#!/usr/bin/env python3
"""Serve one owned image generation at a time behind the Vulkan workload lease.

Two sockets carry two different authorities. A Unix socket in the private state
directory takes `image_generate`, `cancel`, and `status` as JSON lines, because
a control channel that starts GPU work belongs to the filesystem permissions of
the serving user rather than to a port. A loopback HTTP listener serves
completed immutable artifacts alone: `GET /health`,
`GET /artifacts/<sha256>.png`, and `GET /artifacts/<sha256>.json` each require
the same bearer API key the fallback Web UI sends on every request, and the
bearer check runs ahead of the artifact lookup so a present and an absent hash
answer 401 alike. The hash identifies an artifact and never authenticates a
reader; neither does a query parameter, which the route ignores entirely.
`--lan-exposure ADDRESS` is the operator's explicit opt-in: it admits
`--http-host 0.0.0.0` and adds that one routable literal to the Host headers a
request may name, and the bearer that already gates every route is what a LAN
reader presents. `--lan-name NAME` adds the mDNS hostname beside that literal,
compared casefolded, so the page is reachable at a host a DHCP lease does not
move. `--open-lan` removes the bearer from the artifact routes, which leaves
the admitted Host set and the Origin allowlist carrying the gate.

The job pipeline is one sequence with one owner: parse the request, hand it to
the injected verifier for its profile parameters, refuse every cap violation,
acquire the Vulkan workload lease, verify the one-use grant, spawn the pinned
runtime at an absolute nice of 19 in its own session, validate and hash the
PNG, write independently content-addressed provenance, atomically publish one
marker that makes the pair reachable, and release the lease. Capacity is
reserved before grant verification, so a busy service does not spend approval.

The lease acquisition waits rather than refusing at once. llama-server holds
the same lock from its first busy slot to the last idle one, so the chat turn
that just emitted the approved tool call is still releasing while this request
arrives. `QWEN_IMAGE_LEASE_WAIT_S` bounds that wait at 60 seconds by default
and a value of zero makes one non-blocking attempt; the refusal past the
deadline carries the same `lease_unavailable` reason a held lease always
carried.

The service holds the lease descriptor for the duration of the job and passes
it to nothing. `flock` binds to the open file description, so a descriptor
handed to the runtime would keep the lease held by every grandchild that
inherited it; acquiring at job start and closing at job end holds the lease
exactly across active GPU work. The lease is an image-side lease as it stands:
`patches/llama-server-vulkan-workload-lease.patch` makes llama-server the
second writer of `vulkan-workload.lock` under `QWEN_VULKAN_WORKLOAD_LOCK`, so
the two lanes exclude each other through the kernel once that candidate patch
is admitted on the appliance; a server built without it leaves this an
image-side lease that serializes generations against each other alone.

Two seams are injected because two other lanes own them. `--verifier
MODULE:FUNCTION` names the signed-request verifier, whose contract is
`verify(request) -> profile_parameters`: it receives the whole request
dictionary, raises on a bad signature, an expired term, or a spent nonce, and
returns the validated profile parameters the job runs under. The authorization
lane owns the binding between a grant and the request it was signed over. The
service revalidates the shape of what comes back and enforces the profile's own
ceilings, so a verifier that admits a request still cannot exceed the profile
it returns. The default verifier checks request shape alone and resolves the
profile from `--profiles-json`, a file of already-validated parameters keyed by
profile id, which keeps this service free of any registry TSV reader.

The two deadlines here are the service's own: the whole job from lease
acquisition through rename is bounded at 330 seconds, and the runtime child
carries a hard bound of 300 seconds, SIGTERM first and SIGKILL after a fixed
grace.
"""

import argparse
import binascii
import contextlib
import errno
import fcntl
import hashlib
import hmac
import http.server
import importlib
import json
import math
import os
import re
import resource
import secrets
import signal
import socket
import socketserver
import stat
import struct
import subprocess
import sys
import threading
import time
import zlib

SERVICE_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
if SERVICE_DIRECTORY not in sys.path:
    sys.path.insert(0, SERVICE_DIRECTORY)

import image_protocol as protocol  # noqa: E402

PROTOCOL_VERSION = protocol.PROTOCOL_VERSION
LOOPBACK_HOSTS = ("127.0.0.1", "::1")
ASCII_LABEL_CHARACTERS = frozenset("abcdefghijklmnopqrstuvwxyz0123456789-")
WILDCARD_HOST = "0.0.0.0"  # noqa: S104 -- the exposure opt-in binds it deliberately
RUNTIME_HARD_TIMEOUT_SECONDS = 300
SERVICE_JOB_DEADLINE_SECONDS = 330
TERMINATION_GRACE_SECONDS = 5.0
CONTROL_LINE_BYTE_CAP = protocol.MAX_LINE_BYTES
CONTROL_READ_TIMEOUT_SECONDS = 30.0
ARTIFACT_READ_TIMEOUT_SECONDS = 30.0
ARTIFACT_MAX_CONCURRENT_CONNECTIONS = 8
ARTIFACT_BYTE_CAP = 64 * 1024 * 1024
MEMORY_SAMPLE_INTERVAL_SECONDS = 0.5
LEASE_FILE_NAME = "vulkan-workload.lock"
DEFAULT_LEASE_WAIT_SECONDS = 60.0
LEASE_WAIT_POLL_SECONDS = 0.05
LEASE_STATUS_FILE_NAME = "vulkan-workload.status"
SOCKET_FILE_NAME = "image-service.sock"
PID_FILE_NAME = "image-service.pid"
ARTIFACT_DIRECTORY_NAME = "artifacts"
IMAGE_DIRECTORY_NAME = "images"
PRIVATE_DIRECTORY_MODE = 0o700
DEFAULT_RADV_ICD_PATH = "/usr/share/vulkan/icd.d/radeon_icd.x86_64.json"
ARTIFACT_NAME_PATTERN = re.compile(r"^([0-9a-f]{64})\.(png|json)$")
TEMPLATE_TOKEN_PATTERN = re.compile(r"\{([a-z_]+)\}")
SAMPLER_PATTERN = re.compile(r"^[A-Za-z0-9_+-]{1,32}$")
PLACEMENT_ARMS = ("A", "B", "C")
EXECUTION_POLICY_ADMITTED = "validator-gated"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
PNG_CHANNELS_FOR_COLOR_TYPE = {0: 1, 2: 3, 4: 2, 6: 4}
UNOBSERVED = "-"
REQUIRED_RUNTIME_NICE = 19
PRIORITY_CONFIRMATION_SECONDS = 1.0
PRIORITY_POLL_INTERVAL_SECONDS = 0.002
# The wrapper that places the runtime at nice 19 and the idle I/O class lives
# beside this file; QWEN_IMAGE_PRIORITY_WRAPPER or --priority-wrapper names a
# stand-in for a test. /proc is read through PROCFS_ROOT so a test can point
# the reader at a directory holding no process and reach the unreadable path.
DEFAULT_PRIORITY_WRAPPER = os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "qwen-exec-idle-priority.sh"
)
PROCFS_ROOT = os.environ.get("QWEN_IMAGE_PROCFS_ROOT", "/proc")
# The identifier a reply carries where the request named none the protocol
# admits, since every response echoes an identifier the schema validates.
UNIDENTIFIED_REQUEST = "unidentified"

ACTION_GENERATE, ACTION_CANCEL, ACTION_STATUS = protocol.ACTIONS
ACTIONS = protocol.ACTIONS

# The request keys the control socket admits come from the frozen protocol, so
# the service and the MCP wrapper read one closed schema. A filesystem path
# never appears among them: the service names the `.part.png` file, the
# artifact, and the provenance record from its own state directory, so a
# caller cannot steer a write.
GENERATE_KEYS = protocol.REQUEST_FIELDS

# What the argv template may name. The output path is supplied by the service,
# so `{output}` resolves to a file under the artifact directory and to nothing
# a request can influence.
TEMPLATE_TOKENS = (
    "prompt",
    "negative_prompt",
    "seed",
    "width",
    "height",
    "steps",
    "sampler",
    "cfg",
    "model_path",
    "output",
)

PROFILE_STRING_FIELDS = (
    "profile_id",
    "model_id",
    "placement",
    "sampler",
    "execution_policy",
    "runtime_path",
)
PROFILE_INTEGER_FIELDS = (
    "width",
    "height",
    "steps",
    "max_steps",
    "max_dimension",
    "timeout_s",
)


class ServiceError(Exception):
    """A refusal reported under a fixed reason vocabulary.

    `status` is what the protocol carries and `reason` is the machine-readable
    term beneath it: a request the service declines before any device work is
    `refused`, and a job that reached the runtime and failed there is `failed`.
    """

    status = "refused"
    reason = "invalid_argument"


class InvalidArgument(ServiceError):
    reason = "invalid_argument"


class AuthorizationDenied(ServiceError):
    reason = "authorization_denied"


class ProfileRefused(ServiceError):
    reason = "profile_refused"


class ServiceBusy(ServiceError):
    reason = "busy"


class LeaseUnavailable(ServiceError):
    reason = "lease_unavailable"


class NotRunning(ServiceError):
    """Cancellation reached a service that owns no generation."""

    reason = "not_running"


class RuntimeFailed(ServiceError):
    status = "failed"
    reason = "runtime_failed"


class RuntimeTimeout(ServiceError):
    status = "failed"
    reason = "runtime_timeout"


class InternalFailure(ServiceError):
    """An admitted operation failed outside a declared runtime outcome."""

    status = "failed"
    reason = "internal_error"


class PngInvalid(ServiceError):
    """A produced file fails the PNG contract; `detail` names which rule."""

    status = "failed"
    reason = "png_invalid"

    def __init__(self, message, detail):
        super().__init__(message)
        self.detail = detail


class JobCancelled(ServiceError):
    status = "cancelled"
    reason = "cancelled"


def shape_only_verifier(profiles):
    """Return the default verifier: request shape, then the named profile.

    The MCP lane verifies the grant before a request reaches this socket, so
    the default admits a well-formed request and resolves its profile from the
    parameters a launch handed in. `--verifier` replaces it with the
    authorization lane's own callable, which binds the opaque grant to the
    request before returning the same profile dictionary.
    """

    def verify(request):
        for field in ("profile_id", "width", "height", "steps"):
            if field not in request:
                raise InvalidArgument(f"{field} is required")
        profile = profiles.get(request["profile_id"])
        if profile is None:
            raise ProfileRefused(f"no image profile named {request['profile_id']!r}")
        return profile

    return verify


def load_verifier(specification):
    """Return the `verify(request) -> profile_parameters` callable a launch names."""
    if ":" not in specification:
        raise argparse.ArgumentTypeError(
            "the verifier is named MODULE:FUNCTION, so that the authorization "
            f"lane plugs its own callable in; {specification!r} names no function"
        )
    module_name, function_name = specification.rsplit(":", 1)
    module = importlib.import_module(module_name)
    verifier = getattr(module, function_name, None)
    if not callable(verifier):
        raise argparse.ArgumentTypeError(f"{specification} names no callable")
    return verifier


def loopback_host(value):
    """Return a host the HTTP listener admits, or raise for any other.

    The refusal runs against the configured string before the socket exists, so
    a wider bind fails at startup rather than serving artifacts to the network
    until somebody reads the listening address. `--lan-exposure` widens this to
    the wildcard, and `main` pairs the two.
    """
    if value in LOOPBACK_HOSTS or value == WILDCARD_HOST:
        return value
    raise argparse.ArgumentTypeError(
        f"the artifact listener binds a loopback literal or {WILDCARD_HOST}; "
        f"{value!r} is refused. Admitted hosts: "
        f"{', '.join((*LOOPBACK_HOSTS, WILDCARD_HOST))}"
    )


def exposed_host(value):
    """Return the IPv4 literal the LAN exposure opt-in admits in a Host header.

    The comparison stays literal, so the DNS rebinding defense survives the
    opt-in: a name resolving to the bound address is refused under the exposure
    the way it is under the loopback default. The wildcard names no address a
    reader reaches, so it belongs in `--http-host` and never here.
    """
    if not value:
        # argparse applies a string type to its own default, so the empty
        # default passes through as the absent opt-in.
        return ""
    parts = value.split(".")
    if len(parts) != 4 or not all(
        part.isdigit() and len(part) <= 3 and 0 <= int(part) <= 255 for part in parts
    ):
        raise argparse.ArgumentTypeError(
            f"the LAN exposure address is an IPv4 literal; {value!r} is refused"
        )
    if value in LOOPBACK_HOSTS or value == WILDCARD_HOST:
        raise argparse.ArgumentTypeError(
            f"the LAN exposure address departs from the loopback default and "
            f"names a reachable address; {value!r} is the default or the wildcard"
        )
    return value


def exposed_name(value):
    """Return the mDNS hostname the LAN exposure opt-in admits beside the literal.

    A DHCP lease moves the address, so the name is what an operator bookmarks.
    Admitting it keeps the set closed rather than reopening the resolver: avahi
    publishes `<hostname>.local` on the link and a browser resolves that suffix
    by multicast to the hosts sharing the link, so a name an attacker controls
    in DNS resolves nowhere near this socket and the rebinding closure the
    literal set provides holds for this entry too. `localhost` and an
    all-numeric dotted form are refused by name: the first names the loopback
    the set already holds and the second is an address `--lan-exposure` takes.
    """
    if not value:
        # argparse applies a string type to its own default, so the empty
        # default passes through as the absent opt-in.
        return ""
    lowered = value.lower()
    if len(lowered) > 253 or lowered == "localhost" or lowered in LOOPBACK_HOSTS:
        raise argparse.ArgumentTypeError(
            f"the LAN exposure name is a hostname a browser resolves on the "
            f"link; {value!r} is refused"
        )
    labels = lowered.split(".")
    if not all(label_is_admitted(label) for label in labels):
        raise argparse.ArgumentTypeError(
            f"the LAN exposure name carries a label outside the "
            f"letter-digit-hyphen set; {value!r} is refused"
        )
    if all(label.isdigit() for label in labels):
        raise argparse.ArgumentTypeError(
            f"the LAN exposure name is a dotted address rather than a name; "
            f"{value!r} belongs in --lan-exposure"
        )
    return lowered


def label_is_admitted(label):
    """Return whether one hostname label meets the ASCII letter-digit-hyphen rule.

    The character set stays ASCII rather than reading `str.isalnum`, which
    admits every Unicode letter: a browser sends an internationalized name in
    its Punycode form, so a name outside ASCII is refused here rather than
    admitted into a set no request ever matches.
    """
    return (
        1 <= len(label) <= 63
        and not label.startswith("-")
        and not label.endswith("-")
        and all(character in ASCII_LABEL_CHARACTERS for character in label)
    )


def admitted_hosts(exposure="", name=""):
    """Return the Host-header names a request may present.

    The loopback literals stand under every setting, because `image-review.py`
    and the teardown check reach this listener over 127.0.0.1 whatever the
    socket binds. The exposure adds exactly one literal and the name adds
    exactly one lowercased hostname, so the set stays a closed list.
    """
    admitted = list(LOOPBACK_HOSTS)
    if exposure:
        admitted.append(exposure)
    if name:
        admitted.append(name)
    return tuple(admitted)


def host_header_names(header, admitted):
    """Return whether a Host header names one of the admitted entries.

    A browser that resolves an attacker-controlled name to a bound address
    reaches this socket with that name in the Host header, so the bind alone
    leaves DNS rebinding open; comparing the header against a closed set closes
    it. The comparison falls back to the casefolded form because DNS names are
    case-insensitive and the admitted name is stored lowercased, while the
    literals hold digits and dots alone.
    """
    if not header:
        return ""
    value = header.strip()
    if value.startswith("["):
        closing = value.find("]")
        if closing < 0:
            return ""
        named = value[1:closing]
    else:
        named = value.split(":", 1)[0]
    if named in admitted:
        return named
    lowered = named.lower()
    return lowered if lowered in admitted else ""


def host_header_is_loopback(header):
    """Return whether a Host header names a loopback literal and no other name."""
    return bool(host_header_names(header, LOOPBACK_HOSTS))


def derive_radv_icd_environment():
    """Return the RADV ICD pin every spawned runtime process inherits.

    remote/radv-icd-env.sh derives the identical pair by sourcing it into a
    shell caller: QWEN_RADV_ICD names the ICD JSON, defaulting to
    DEFAULT_RADV_ICD_PATH, and VK_DRIVER_FILES and VK_ICD_FILENAMES both
    carry it so the Vulkan loader enumerates RADV alone and lavapipe never
    appears to the runtime's --list-devices or a generation arm. This
    service derives the same path in Python rather than sourcing that file,
    because a Python process has no shell to source it into; the derivation
    is documented here as the second reading of one rule.
    """
    radv_icd_path = os.environ.get("QWEN_RADV_ICD", DEFAULT_RADV_ICD_PATH)
    if not os.access(radv_icd_path, os.R_OK):
        raise InvalidArgument(f"RADV ICD is not readable: {radv_icd_path}")
    return {"VK_DRIVER_FILES": radv_icd_path, "VK_ICD_FILENAMES": radv_icd_path}


def read_secret_file(path, purpose):
    """Return the contents of a key file that only its owner reads.

    The descriptor opens with O_NOFOLLOW, O_CLOEXEC, and O_NONBLOCK, so a
    symlink planted at the configured path fails the open rather than
    redirecting the read, no child inherits the descriptor, and a FIFO returns
    at once for the regular-file check rather than waiting for a writer. The
    regular-file and mode checks run against fstat of that same descriptor,
    which leaves no window between the check and the read for a replacement.
    """
    if not path:
        raise InvalidArgument(f"the {purpose} key file is unconfigured")
    try:
        descriptor = os.open(
            path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
        )
    except OSError:
        raise InvalidArgument(f"the {purpose} key file is unreadable: {path}") from None
    try:
        file_status = os.fstat(descriptor)
        if not stat.S_ISREG(file_status.st_mode):
            raise InvalidArgument(
                f"the {purpose} key file is not a regular file: {path}"
            )
        mode = stat.S_IMODE(file_status.st_mode)
        if mode & 0o077:
            raise InvalidArgument(
                f"the {purpose} key file {path} is mode {mode:04o}; 0600 is "
                "required before the service starts"
            )
        raw = os.read(descriptor, 4096)
    finally:
        os.close(descriptor)
    try:
        secret = raw.decode("utf-8").strip()
    except UnicodeDecodeError:
        raise InvalidArgument(
            f"the {purpose} key file is not UTF-8 text: {path}"
        ) from None
    if not secret:
        raise InvalidArgument(f"the {purpose} key file is empty: {path}")
    return secret


def utc_timestamp(epoch):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(epoch))


def sha256_text(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require_deadline(deadline, stage):
    """Fail an admitted job when finalization passes its monotonic bound."""
    if time.monotonic() > deadline:
        raise RuntimeTimeout(
            f"the job passed the {SERVICE_JOB_DEADLINE_SECONDS} second service "
            f"deadline during {stage}"
        )


def write_private_bytes(path, body):
    """Create one private durable staging file without following a prior path."""
    descriptor = os.open(
        path,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC,
        0o600,
    )
    try:
        with os.fdopen(descriptor, "wb", closefd=False) as handle:
            handle.write(body)
            handle.flush()
            os.fsync(handle.fileno())
    finally:
        os.close(descriptor)


def fsync_directory(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def aspect_ratio(width, height):
    """Return the reduced `w:h` string a request declares an aspect with."""
    divisor = math.gcd(width, height)
    return f"{width // divisor}:{height // divisor}"


def validate_profile(profile):
    """Return the profile parameters after checking every field the job uses.

    The verifier hands this dictionary in already validated against the
    registry, and this function checks the shape the pipeline depends on, so a
    caller that skips a field fails here rather than inside the spawn.
    `execution_policy` is checked at admission time rather than here, because a
    `refused` row is a well-formed row.
    """
    if not isinstance(profile, dict):
        raise ProfileRefused("the profile parameters are not an object")
    for field in PROFILE_STRING_FIELDS:
        value = profile.get(field)
        if not isinstance(value, str) or not value:
            raise ProfileRefused(f"the profile field {field} is absent or empty")
    for field in PROFILE_INTEGER_FIELDS:
        value = profile.get(field)
        if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
            raise ProfileRefused(f"the profile field {field} is not a positive integer")
    if profile["placement"] not in PLACEMENT_ARMS:
        raise ProfileRefused(
            f"the profile names placement arm {profile['placement']!r}; the "
            f"admitted arms are {', '.join(PLACEMENT_ARMS)}"
        )
    if not SAMPLER_PATTERN.match(profile["sampler"]):
        raise ProfileRefused("the profile sampler carries characters outside the set")
    cfg = profile.get("cfg")
    if (
        not isinstance(cfg, (int, float))
        or isinstance(cfg, bool)
        or not math.isfinite(cfg)
        or cfg < 0
    ):
        raise ProfileRefused("the profile field cfg is not a non-negative number")
    if profile["steps"] > profile["max_steps"]:
        raise ProfileRefused("the profile default steps exceed its own max_steps")
    for field in ("width", "height"):
        if profile[field] > profile["max_dimension"]:
            raise ProfileRefused(
                f"the profile default {field} exceeds its own max_dimension"
            )
    if not os.path.isabs(profile["runtime_path"]):
        raise ProfileRefused("the profile runtime_path is not absolute")
    model_path = profile.get("model_path", "")
    if not isinstance(model_path, str) or (
        model_path and not os.path.isabs(model_path)
    ):
        raise ProfileRefused("the profile model_path is not an absolute path")
    argv_template = profile.get("runtime_argv")
    if not isinstance(argv_template, list) or not all(
        isinstance(entry, str) for entry in argv_template
    ):
        raise ProfileRefused("the profile runtime_argv is not a list of strings")
    for entry in argv_template:
        for token in TEMPLATE_TOKEN_PATTERN.findall(entry):
            if token not in TEMPLATE_TOKENS:
                raise ProfileRefused(
                    f"the argv template names {{{token}}}, which is outside the "
                    f"substitution set {', '.join(TEMPLATE_TOKENS)}"
                )
    return profile


def render_argv(profile, substitutions):
    """Return the runtime argv with every template token replaced by a value.

    The rendering runs over the validated token set in one pass, so a
    caller-supplied string never becomes a template of its own: a brace inside
    a prompt stays a literal brace in the argument the runtime receives.
    """

    def replace(match):
        return str(substitutions[match.group(1)])

    return [profile["runtime_path"]] + [
        TEMPLATE_TOKEN_PATTERN.sub(replace, entry) for entry in profile["runtime_argv"]
    ]


def parse_png(raw, expected_width, expected_height):
    """Return the IHDR fields of a PNG whose chunks, CRCs, and pixels decode.

    A runtime that dies mid-write leaves a file with a valid signature and a
    truncated chunk stream, and a runtime that ignores the requested geometry
    leaves a complete file of the wrong size; both answer rather than error, so
    every artifact is read whole before it is named. The raw-scanline length
    check is exact for a non-interlaced image, which is why Adam7 is refused as
    unsupported rather than measured against a formula that does not apply.
    """
    if not raw.startswith(PNG_SIGNATURE):
        raise PngInvalid("the produced file carries no PNG signature", "signature")
    offset = len(PNG_SIGNATURE)
    header = None
    compressed = bytearray()
    saw_end = False
    while offset < len(raw):
        if saw_end:
            raise PngInvalid("bytes follow the IEND chunk", "trailing_bytes")
        if offset + 8 > len(raw):
            raise PngInvalid("a chunk header is truncated", "truncated")
        (length,) = struct.unpack(">I", raw[offset : offset + 4])
        kind = raw[offset + 4 : offset + 8]
        body_start = offset + 8
        body_end = body_start + length
        if body_end + 4 > len(raw):
            raise PngInvalid(
                f"the {kind.decode('ascii', 'replace')} chunk is truncated",
                "truncated",
            )
        body = raw[body_start:body_end]
        (stored_crc,) = struct.unpack(">I", raw[body_end : body_end + 4])
        if binascii.crc32(kind + body) & 0xFFFFFFFF != stored_crc:
            raise PngInvalid(
                f"the {kind.decode('ascii', 'replace')} chunk fails its CRC",
                "checksum",
            )
        if header is None and kind != b"IHDR":
            raise PngInvalid("the first chunk is not IHDR", "header")
        if kind == b"IHDR":
            if length != 13:
                raise PngInvalid("the IHDR chunk is not 13 bytes", "header")
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            compressed.extend(body)
        elif kind == b"IEND":
            saw_end = True
        offset = body_end + 4
    if header is None or not saw_end:
        raise PngInvalid("the chunk stream ends before IEND", "truncated")
    width, height, bit_depth, color_type, compression, filter_method, interlace = header
    if width != expected_width or height != expected_height:
        raise PngInvalid(
            f"the produced image is {width}x{height} where the request named "
            f"{expected_width}x{expected_height}",
            "dimension",
        )
    if (
        bit_depth != 8
        or interlace != 0
        or color_type not in PNG_CHANNELS_FOR_COLOR_TYPE
    ):
        raise PngInvalid(
            f"the image is bit depth {bit_depth}, colour type {color_type}, "
            f"interlace {interlace}; the service admits 8-bit non-interlaced "
            "greyscale and truecolour, each with or without alpha",
            "unsupported",
        )
    if compression != 0 or filter_method != 0:
        raise PngInvalid(
            "the image names a compression or filter method the format does "
            "not define",
            "unsupported",
        )
    channels = PNG_CHANNELS_FOR_COLOR_TYPE[color_type]
    expected_bytes = height * (1 + width * channels)
    decompressor = zlib.decompressobj()
    try:
        scanlines = decompressor.decompress(bytes(compressed), expected_bytes + 1)
        if len(scanlines) > expected_bytes or decompressor.unconsumed_tail:
            raise PngInvalid(
                "the image data expands beyond the declared geometry", "decode"
            )
        scanlines += decompressor.flush(expected_bytes - len(scanlines) + 1)
    except zlib.error as error:
        raise PngInvalid(f"the image data fails to decode: {error}", "decode") from None
    if not decompressor.eof or decompressor.unused_data:
        raise PngInvalid("the image data stream is incomplete", "decode")
    if len(scanlines) != expected_bytes:
        raise PngInvalid(
            f"the image decodes to {len(scanlines)} bytes where {expected_bytes} "
            "describe the declared geometry",
            "decode",
        )
    row_bytes = 1 + width * channels
    for row_offset in range(0, expected_bytes, row_bytes):
        if scanlines[row_offset] > 4:
            raise PngInvalid(
                f"scanline {row_offset // row_bytes} uses undefined PNG filter "
                f"{scanlines[row_offset]}",
                "filter",
            )
    return {
        "width": width,
        "height": height,
        "bit_depth": bit_depth,
        "color_type": color_type,
        "channels": channels,
    }


def artifact_read_timeout_seconds_from_environment():
    """Read the artifact listener's per-socket read timeout, refusing a bad value.

    `QWEN_IMAGE_ARTIFACT_READ_TIMEOUT_S` lets a test shrink the bound the
    wildcard listener otherwise holds an idle or partial-request connection
    under for `ARTIFACT_READ_TIMEOUT_SECONDS`, the way
    `QWEN_IMAGE_LEASE_WAIT_S` shrinks the lease wait; a malformed or negative
    setting would silently become the default and hide a launch that meant to
    configure it, so it raises instead.
    """
    raw = os.environ.get("QWEN_IMAGE_ARTIFACT_READ_TIMEOUT_S", "")
    if raw == "":
        return ARTIFACT_READ_TIMEOUT_SECONDS
    try:
        seconds = float(raw)
    except ValueError:
        raise ServiceError(
            f"QWEN_IMAGE_ARTIFACT_READ_TIMEOUT_S is not a number: {raw}"
        ) from None
    if seconds <= 0 or seconds != seconds:
        raise ServiceError(
            f"QWEN_IMAGE_ARTIFACT_READ_TIMEOUT_S is not positive: {raw}"
        )
    return seconds


def lease_wait_seconds_from_environment():
    """Read the bounded lease wait, refusing a value the deadline cannot use.

    A malformed or negative setting would silently become the default and hide
    a launch that meant to configure the wait, so it raises instead.
    """
    raw = os.environ.get("QWEN_IMAGE_LEASE_WAIT_S", "")
    if raw == "":
        return DEFAULT_LEASE_WAIT_SECONDS
    try:
        seconds = float(raw)
    except ValueError:
        raise ServiceError(
            f"QWEN_IMAGE_LEASE_WAIT_S is not a number: {raw}"
        ) from None
    if seconds < 0 or seconds != seconds:
        raise ServiceError(f"QWEN_IMAGE_LEASE_WAIT_S is negative: {raw}")
    return seconds


class WorkloadLease:
    """The Vulkan workload lease, a kernel lock with an observed status line.

    `flock` on the descriptor is the authority: it releases when the process
    exits however it exits, so a killed service leaves no lease behind. The
    text file beside it records who holds it and since when, which a reader
    consults and no code trusts.
    """

    def __init__(self, state_directory, wait_seconds=None):
        self.lock_path = os.path.join(state_directory, LEASE_FILE_NAME)
        self.status_path = os.path.join(state_directory, LEASE_STATUS_FILE_NAME)
        self.descriptor = None
        if wait_seconds is None:
            wait_seconds = lease_wait_seconds_from_environment()
        self.wait_seconds = wait_seconds

    def acquire(self, holder, job_id, cancelled=None):
        """Take the lease, waiting up to `wait_seconds` for a live holder.

        A monotonic deadline is what bounds the wait, and `flock` offers no
        timeout: bounding a blocking call would take SIGALRM, whose delivery
        thread is unspecified in a process that runs the memory sampler and the
        listener beside this one. The poll costs one syscall every 50 ms and
        needs no signal. A zero deadline makes exactly one attempt.
        """
        if self.descriptor is not None:
            raise LeaseUnavailable("this service already holds the workload lease")
        descriptor = os.open(
            self.lock_path, os.O_RDWR | os.O_CREAT | os.O_CLOEXEC, 0o644
        )
        deadline = time.monotonic() + self.wait_seconds
        while True:
            if cancelled is not None and cancelled():
                os.close(descriptor)
                raise JobCancelled(
                    "the generation was cancelled while waiting for the workload lease"
                )
            try:
                fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError as error:
                if error.errno not in (errno.EACCES, errno.EAGAIN):
                    os.close(descriptor)
                    raise
                if time.monotonic() >= deadline:
                    os.close(descriptor)
                    raise LeaseUnavailable(
                        "another Vulkan workload holds the lease; one workload "
                        "runs at a time"
                    ) from None
                time.sleep(LEASE_WAIT_POLL_SECONDS)
        if cancelled is not None and cancelled():
            fcntl.flock(descriptor, fcntl.LOCK_UN)
            os.close(descriptor)
            raise JobCancelled(
                "the generation was cancelled as it acquired the workload lease"
            )
        self.descriptor = descriptor
        self.write_status(
            f"state=held holder={holder} pid={os.getpid()} job={job_id} "
            f"since={utc_timestamp(time.time())}"
        )

    def write_status(self, line):
        with contextlib.suppress(OSError):
            with open(self.status_path, "w", encoding="ascii") as handle:
                handle.write(line + "\n")

    def release(self):
        if self.descriptor is None:
            return
        try:
            fcntl.flock(self.descriptor, fcntl.LOCK_UN)
        finally:
            os.close(self.descriptor)
            self.descriptor = None
        self.write_status(
            f"state=released pid={os.getpid()} at={utc_timestamp(time.time())}"
        )

    @property
    def held(self):
        return self.descriptor is not None


class MemorySampler(threading.Thread):
    """Record the host memory floor a generation runs against.

    MemAvailable at one instant describes nothing about a job that allocates
    for two minutes, so the minimum over the run is the observation retained,
    and the swap fields are read at both ends for their difference.
    """

    daemon = True

    def __init__(self):
        super().__init__()
        self.stop_event = threading.Event()
        self.minimum_available_kib = None
        self.swap_free_start_kib = None
        self.swap_free_end_kib = None

    @staticmethod
    def read_meminfo():
        fields = {}
        try:
            with open("/proc/meminfo", encoding="ascii") as handle:
                for line in handle:
                    name, _, rest = line.partition(":")
                    parts = rest.split()
                    if parts and parts[0].isdigit():
                        fields[name] = int(parts[0])
        except OSError:
            return {}
        return fields

    def sample(self):
        fields = self.read_meminfo()
        available = fields.get("MemAvailable")
        if available is not None:
            if self.minimum_available_kib is None:
                self.minimum_available_kib = available
            else:
                self.minimum_available_kib = min(self.minimum_available_kib, available)
        return fields.get("SwapFree")

    def run(self):
        self.swap_free_start_kib = self.sample()
        while not self.stop_event.wait(MEMORY_SAMPLE_INTERVAL_SECONDS):
            self.sample()
        self.swap_free_end_kib = self.sample()

    def finish(self):
        self.stop_event.set()
        self.join(timeout=MEMORY_SAMPLE_INTERVAL_SECONDS * 4)
        if self.swap_free_start_kib is None or self.swap_free_end_kib is None:
            return UNOBSERVED
        return self.swap_free_start_kib - self.swap_free_end_kib


def read_process_nice(pid):
    """Return field 19 of `/proc/PID/stat`, the child's nice value.

    The priority is read back rather than asserted, because the value the
    service requested and the value the kernel applied are two claims. The comm
    field may hold spaces, so the fields are counted from its closing
    parenthesis.
    """
    try:
        with open(f"{PROCFS_ROOT}/{pid}/stat", encoding="ascii") as handle:
            fields = handle.read().rsplit(")", 1)[1].split()
        return int(fields[16])
    except (OSError, IndexError, ValueError):
        return None


def wait_for_process_nice(pid, required=REQUIRED_RUNTIME_NICE, timeout_seconds=1.0):
    """Poll the kernel until the pid's nice equals `required` or time runs out.

    The wrapper applies the priority inside the child after the spawn returns,
    so the first reading is the value the child inherited and the required
    value appears once `renice` has run. The last observed value is returned,
    which is `required` on success, another integer when the deadline passed
    with the priority elsewhere, and None when the entry was unreadable at the
    deadline.
    """
    deadline = time.monotonic() + timeout_seconds
    observed = read_process_nice(pid)
    while observed != required and time.monotonic() < deadline:
        time.sleep(PRIORITY_POLL_INTERVAL_SECONDS)
        observed = read_process_nice(pid)
    return observed


def read_process_ioclass(pid):
    """Return the I/O scheduling class ionice(1) reports for the pid, or None.

    The kernel exposes the class through ioprio_get(2) alone, so the reading
    goes through /usr/bin/ionice rather than a /proc file. The first word of
    its output is the class name, `idle` for the class the wrapper applied.
    """
    try:
        completed = subprocess.run(
            ["/usr/bin/ionice", "-p", str(pid)],
            capture_output=True,
            text=True,
            check=False,
            env={"LC_ALL": "C", "PATH": "/usr/bin:/bin"},
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if completed.returncode != 0 or not completed.stdout.split():
        return None
    return completed.stdout.split()[0].rstrip(":")


def live_process_group_members(process_group_id):
    """Return live Linux processes in the runtime's process group.

    Zombies retain their process-group identifier but execute no code and own
    no Vulkan workload, so the state from the same procfs snapshot excludes
    them from the live-member result.
    """
    try:
        entries = os.listdir("/proc")
    except OSError:
        return None
    members = []
    for entry in entries:
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/stat", encoding="ascii") as handle:
                fields = handle.read().rsplit(")", 1)[1].split()
            process_state = fields[0]
            member_group = int(fields[2])
        except (OSError, IndexError, ValueError):
            continue
        if member_group == process_group_id and process_state != "Z":
            members.append(int(entry))
    return sorted(members)


class JobState:
    """What a running job exposes to `status` and `cancel` while it runs.

    Every field is written under the lock and every reader takes the lock for
    the length of one dictionary copy, so `status` answers while the runtime is
    still executing and `cancel` reaches the child without waiting on it.
    """

    def __init__(self):
        self.lock = threading.Lock()
        self.job_id = ""
        self.request_id = ""
        self.profile_id = ""
        self.started_at = 0.0
        self.started_monotonic = 0.0
        self.child_pid = 0
        self.part_path = ""
        self.cancel_requested = False
        self.phase = "idle"


class ImageService:
    """One generation at a time, from a verified request to a named artifact."""

    def __init__(self, settings):
        self.settings = settings
        self.lease = WorkloadLease(settings.state_directory)
        self.artifact_directory = os.path.join(
            settings.image_directory, ARTIFACT_DIRECTORY_NAME
        )
        os.makedirs(self.artifact_directory, mode=PRIVATE_DIRECTORY_MODE, exist_ok=True)
        self.recover_legacy_publications()
        self.job_lock = threading.Lock()
        self.job = JobState()
        self.shutdown_event = threading.Event()

    def publication_records(self):
        """Yield complete publication markers from atomic directory entries."""
        try:
            names = os.listdir(self.artifact_directory)
        except OSError:
            return
        for name in names:
            if not name.startswith(".publication-") or not name.endswith(".json"):
                continue
            path = os.path.join(self.artifact_directory, name)
            try:
                with open(path, encoding="utf-8") as handle:
                    record = json.load(handle)
            except (OSError, ValueError):
                continue
            if isinstance(record, dict):
                yield record

    def artifact_is_published(self, digest, suffix):
        """Return whether one atomic marker commits the requested pair."""
        key = "png_sha256" if suffix == "png" else "provenance_sha256"
        for record in self.publication_records():
            if record.get(key) != digest:
                continue
            png_path = os.path.join(
                self.artifact_directory, f"{record.get('png_sha256', '')}.png"
            )
            provenance_path = os.path.join(
                self.artifact_directory,
                f"{record.get('provenance_sha256', '')}.json",
            )
            if os.path.isfile(png_path) and os.path.isfile(provenance_path):
                return True
        return False

    def recover_legacy_publications(self):
        """Commit complete pre-marker PNG/JSON pairs without exposing orphans."""
        try:
            names = os.listdir(self.artifact_directory)
        except OSError:
            return
        for name in names:
            match = ARTIFACT_NAME_PATTERN.match(name)
            if match is None or match.group(2) != "json":
                continue
            digest = match.group(1)
            png_path = os.path.join(self.artifact_directory, f"{digest}.png")
            if not os.path.isfile(png_path):
                continue
            marker_path = os.path.join(
                self.artifact_directory, f".publication-legacy-{digest}.json"
            )
            if os.path.exists(marker_path):
                continue
            marker_part = f"{marker_path}.part"
            body = json.dumps(
                {
                    "schema": "qwen-image-publication/1",
                    "job_id": "legacy",
                    "png_sha256": digest,
                    "provenance_sha256": digest,
                },
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8") + b"\n"
            try:
                write_private_bytes(marker_part, body)
                os.replace(marker_part, marker_path)
                fsync_directory(self.artifact_directory)
            finally:
                with contextlib.suppress(OSError):
                    os.unlink(marker_part)

    def parse_generate(self, payload):
        """Return the exact fields a generate request names, and no others.

        `image_protocol.validate_request` is the closed schema: an unknown key
        is refused rather than ignored, so a caller that names an output path,
        a model file, or a runtime argument reaches an argument error instead
        of a silently dropped field, and the seed, dimension, step, and aspect
        bounds are the ones the MCP wrapper and the page read from the same
        module. The prompt reaches the runtime as an argument, so a whitespace
        prompt is refused here where the frame admits any string.

        The wire names the shape by label and the provenance record names it as
        a reduced ratio: `square` states what the request and its grant agree
        on, and `1:1` states what the retained record measures.
        """
        try:
            protocol.validate_request(payload)
        except protocol.ProtocolError as breach:
            raise InvalidArgument(str(breach)) from None
        prompt = payload["prompt"]
        if not prompt.strip():
            raise InvalidArgument("prompt must be a non-empty string")
        if not payload["authorization"].strip():
            raise InvalidArgument("authorization must be an opaque string")
        request = {
            "authorization": payload["authorization"],
            "profile_id": payload["profile_id"],
            "prompt": prompt,
            "negative_prompt": payload["negative_prompt"],
            "seed": payload["seed"],
            "width": payload["width"],
            "height": payload["height"],
            "steps": payload["steps"],
            "aspect": aspect_ratio(payload["width"], payload["height"]),
        }
        return request

    def admit(self, request, profile):
        """Refuse every cap violation before the lease is touched.

        Execution policy and the profile's own ceilings are decided ahead of
        `flock`, so a refused request leaves an ordinary LLM turn holding the
        GPU undisturbed. The profile bounds the request whatever the verifier
        admitted, so a grant cannot exceed the row it names.
        """
        if profile["execution_policy"] != EXECUTION_POLICY_ADMITTED:
            raise ProfileRefused(
                f"profile {profile['profile_id']} carries execution_policy "
                f"{profile['execution_policy']!r}; {EXECUTION_POLICY_ADMITTED} "
                "is the only policy that reaches a runtime"
            )
        if profile["profile_id"] != request["profile_id"]:
            raise ProfileRefused(
                f"the verifier returned profile {profile['profile_id']!r} for a "
                f"request naming {request['profile_id']!r}"
            )
        if request["width"] > profile["max_dimension"] or (
            request["height"] > profile["max_dimension"]
        ):
            raise ProfileRefused(
                f"the request names {request['width']}x{request['height']} where "
                f"the profile bounds either side at {profile['max_dimension']}"
            )
        if request["steps"] > profile["max_steps"]:
            raise ProfileRefused(
                f"the request names {request['steps']} steps where the profile "
                f"bounds them at {profile['max_steps']}"
            )
        runtime_path = profile["runtime_path"]
        if not os.path.isfile(runtime_path) or not os.access(runtime_path, os.X_OK):
            raise ProfileRefused(
                f"the profile runtime is absent or not executable: {runtime_path}"
            )

    def handle_generate(self, payload, request_id):
        request = self.parse_generate(payload)
        if self.shutdown_event.is_set():
            raise ServiceBusy("the image service is shutting down")
        if not self.job_lock.acquire(blocking=False):
            raise ServiceBusy(
                "a generation is already running; the service runs one Vulkan "
                "workload at a time and offers no queue"
            )
        try:
            if self.shutdown_event.is_set():
                raise ServiceBusy("the image service is shutting down")
            return self.run_job(payload, request, request_id)
        finally:
            self.job_lock.release()

    def job_cancelled(self):
        """Return the cancellation bit under the same lock as its writer."""
        with self.job.lock:
            return self.shutdown_event.is_set() or self.job.cancel_requested

    def run_job(self, payload, request, request_id):
        """Reserve capacity, consume authorization, run, and publish one job."""
        job_id = secrets.token_hex(8)
        started_at = time.time()
        started_monotonic = time.monotonic()
        deadline = started_monotonic + SERVICE_JOB_DEADLINE_SECONDS
        # The pinned runtime picks its encoder from the output path's own
        # extension and appends `.png` itself when that path names none it
        # recognizes (examples/cli/main.cpp at de298c225bed97c3f9026b73cd7b71
        # e7879bd41b, lines 458-472 and 549-557 of stable-diffusion.cpp): an
        # extensionless `.part` name left the runtime writing `.part.png`
        # while this service waited on the bare name and read "wrote no
        # file". Naming the partial artifact `.part.png` keeps the `.part`
        # marker and gives the runtime's own encoder-selection rule a
        # recognized extension, so the file the runtime writes and the file
        # this service waits on are the same path.
        part_path = os.path.join(self.artifact_directory, f"{job_id}.part.png")
        with self.job.lock:
            if self.shutdown_event.is_set():
                raise JobCancelled("the image service is shutting down")
            self.job.job_id = job_id
            self.job.request_id = request_id
            self.job.profile_id = request["profile_id"]
            self.job.started_at = started_at
            self.job.started_monotonic = started_monotonic
            self.job.part_path = part_path
            self.job.child_pid = 0
            self.job.cancel_requested = False
            self.job.phase = "waiting_for_lease"
        sampler = None
        try:
            # Reserve local and Vulkan capacity before the verifier spends a
            # one-use grant. A busy service therefore returns the approval to
            # its owner instead of consuming it on a job that cannot start.
            self.lease.acquire("image-service", job_id, self.job_cancelled)
            with self.job.lock:
                if self.shutdown_event.is_set() or self.job.cancel_requested:
                    raise JobCancelled(
                        "the generation was cancelled before authorization"
                    )
                self.job.phase = "admitting"
            try:
                verified_profile = self.settings.verifier(dict(payload))
            except ServiceError:
                raise
            except Exception as error:
                raise ProfileRefused(
                    f"the request verifier refused the job: {error}"
                ) from None
            profile = validate_profile(verified_profile)
            self.admit(request, profile)
            with self.job.lock:
                if self.shutdown_event.is_set() or self.job.cancel_requested:
                    raise JobCancelled(
                        "the generation was cancelled before runtime startup"
                    )
                self.job.profile_id = profile["profile_id"]
                self.job.phase = "running"
            sampler = MemorySampler()
            sampler.start()
            outcome = self.execute_runtime(request, profile, part_path, deadline)
            outcome["swap_delta_kib"] = sampler.finish()
            outcome["memavailable_minimum_kib"] = (
                sampler.minimum_available_kib
                if sampler.minimum_available_kib is not None
                else UNOBSERVED
            )
            if time.monotonic() > deadline:
                raise RuntimeTimeout(
                    f"the job passed the {SERVICE_JOB_DEADLINE_SECONDS} second "
                    "service deadline before the artifact was named"
                )
            return self.finish_artifact(
                request,
                profile,
                job_id,
                part_path,
                started_at,
                started_monotonic,
                deadline,
                outcome,
            )
        finally:
            if sampler is not None:
                sampler.stop_event.set()
            with contextlib.suppress(OSError):
                os.unlink(part_path)
            with self.job.lock:
                self.lease.release()
                self.job.phase = "idle"
                self.job.child_pid = 0
                self.job.part_path = ""

    def execute_runtime(self, request, profile, part_path, deadline):
        """Spawn the pinned runtime through the priority wrapper and wait.

        The wrapper places its own pid at nice 19 and the idle I/O class and
        execs the runtime in place; this side confirms nice 19 from the kernel
        within a bounded wait and refuses the job when the reading is absent
        or different. The child runs in its own session, so a runtime that forks is signalled
        as a process group rather than leaving workers on the device. The hard
        timeout is the smaller of the profile's own bound and the 300 second
        ceiling; SIGTERM runs first and SIGKILL follows a fixed grace, so a
        runtime that handles the signal writes its own exit and one that
        ignores it still leaves.
        """
        applied_timeout = min(profile["timeout_s"], RUNTIME_HARD_TIMEOUT_SECONDS)
        substitutions = {
            "prompt": request["prompt"],
            "negative_prompt": request["negative_prompt"],
            "seed": request["seed"],
            "width": request["width"],
            "height": request["height"],
            "steps": request["steps"],
            "sampler": profile["sampler"],
            "cfg": profile["cfg"],
            "model_path": profile.get("model_path", ""),
            "output": part_path,
        }
        argv = render_argv(profile, substitutions)
        # The retained argv is rendered a second time with each prompt replaced
        # by its digest, so the provenance record states which arguments the
        # runtime received without carrying the text the record reduces to a
        # hash everywhere else.
        recorded_argv = render_argv(
            profile,
            dict(
                substitutions,
                prompt=f"sha256:{sha256_text(request['prompt'])}",
                negative_prompt=f"sha256:{sha256_text(request['negative_prompt'])}",
            ),
        )
        environment = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": os.environ.get("HOME", ""),
            "LANG": "C",
            "QWEN_IMAGE_RUNTIME_TIMEOUT_SECONDS": str(applied_timeout),
        }
        environment.update(self.settings.runtime_environment)
        # ServiceSettings pins these two names at startup, so their absence
        # here means a later change stopped carrying the pin into this
        # dictionary; the runtime never spawns against a Vulkan loader that
        # can enumerate lavapipe.
        for required_variable in ("VK_DRIVER_FILES", "VK_ICD_FILENAMES"):
            if not environment.get(required_variable):
                raise InvalidArgument(
                    f"the runtime environment carries no {required_variable}; "
                    "refusing to spawn against an unrestricted Vulkan loader"
                )
        usage_before = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
        spawned_at = time.monotonic()
        # The wrapper is the spawned executable and the runtime is its exec
        # target: it writes nice 19 and the idle I/O class into its own pid,
        # reads both back from the kernel, and replaces itself with the runtime
        # under the same pid, session, and process group. posix_spawn rather
        # than a preexec hook keeps every post-fork step out of Python, since
        # this service is multithreaded and a forked interpreter can block on a
        # lock another thread held.
        wrapper_path = self.settings.priority_wrapper
        with open(os.devnull, "rb") as devnull:
            child_pid = os.posix_spawn(
                wrapper_path,
                [wrapper_path, *argv],
                environment,
                file_actions=[(os.POSIX_SPAWN_DUP2, devnull.fileno(), 0)],
                setsid=True,
            )
        # The pid is published before the priority is confirmed, so a cancel
        # that lands while the wrapper is still applying its priority reaches
        # the wrapper's process group, which is the runtime's process group.
        with self.job.lock:
            self.job.child_pid = child_pid
            cancel_requested = self.job.cancel_requested
        if cancel_requested:
            self.signal_child(child_pid)
        observed_nice = wait_for_process_nice(
            child_pid, REQUIRED_RUNTIME_NICE, PRIORITY_CONFIRMATION_SECONDS
        )
        # The wrapper writes the I/O class after the priority, so the class is
        # polled inside the same confirmation window; the value recorded is
        # what ionice reported at the last reading, and the wrapper's own
        # refusal (status 125) is what ends a runtime whose class stayed
        # elsewhere.
        observed_ioclass = None
        if observed_nice == REQUIRED_RUNTIME_NICE:
            ioclass_deadline = time.monotonic() + PRIORITY_CONFIRMATION_SECONDS
            observed_ioclass = read_process_ioclass(child_pid)
            while observed_ioclass != "idle" and time.monotonic() < ioclass_deadline:
                time.sleep(PRIORITY_POLL_INTERVAL_SECONDS)
                observed_ioclass = read_process_ioclass(child_pid)
        priority_failure = None
        if observed_nice is None:
            priority_failure = (
                "the runtime priority was unreadable after the priority wrapper"
            )
        elif observed_nice != REQUIRED_RUNTIME_NICE:
            priority_failure = (
                f"the runtime ran at nice {observed_nice}; nice "
                f"{REQUIRED_RUNTIME_NICE} is required"
            )
        if priority_failure is not None and not cancel_requested:
            # Fail closed: a runtime whose priority the kernel did not confirm
            # is ended as a process group and reaped before the job is refused.
            self.signal_child(child_pid)
        runtime_deadline = min(spawned_at + applied_timeout, deadline)
        status, timed_out = self.wait_for_child(
            child_pid,
            runtime_deadline,
            termination_requested=cancel_requested or priority_failure is not None,
        )
        elapsed = time.monotonic() - spawned_at
        usage_after = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
        with self.job.lock:
            cancelled = self.job.cancel_requested
            self.job.child_pid = 0
        outcome = {
            "priority_wrapper": wrapper_path,
            "priority_wrapper_sha256": self.settings.priority_wrapper_sha256,
            "runtime_argv": recorded_argv,
            "runtime_pid": child_pid,
            "runtime_seconds": round(elapsed, 3),
            "timeout_s_requested": profile["timeout_s"],
            "timeout_s_applied": applied_timeout,
            "nice": observed_nice if observed_nice is not None else UNOBSERVED,
            "ioclass": observed_ioclass if observed_ioclass is not None else UNOBSERVED,
            # RUSAGE_CHILDREN is a service-lifetime high-water mark on Linux,
            # not a per-job observation. The field names that scope honestly.
            "children_lifetime_maxrss_kib": max(usage_after, usage_before),
        }
        if os.WIFSIGNALED(status):
            outcome["exit_status"] = UNOBSERVED
            outcome["terminating_signal"] = os.WTERMSIG(status)
        else:
            outcome["exit_status"] = os.WEXITSTATUS(status)
            outcome["terminating_signal"] = UNOBSERVED
        if cancelled:
            raise JobCancelled("the generation was cancelled by its owner")
        if priority_failure is not None:
            raise RuntimeFailed(priority_failure)
        if timed_out:
            raise RuntimeTimeout(
                f"the runtime passed its {applied_timeout} second bound and was "
                "terminated"
            )
        if outcome["exit_status"] != 0:
            raise RuntimeFailed(
                f"the runtime exited {outcome['exit_status']} with signal "
                f"{outcome['terminating_signal']}"
            )
        return outcome

    def signal_child(self, child_pid):
        """End the owned child's process group, SIGTERM first."""
        with contextlib.suppress(ProcessLookupError, PermissionError):
            os.killpg(child_pid, signal.SIGTERM)

    def wait_for_child(
        self, child_pid, runtime_deadline, termination_requested=False
    ):
        """Reap the child, terminating on its deadline and killing on grace.

        The shutdown path reaps the same pid while this loop runs, so whichever
        side calls `waitpid` second meets `ChildProcessError`. That is the
        child's departure rather than an error: the loop reports a SIGKILL
        status, which reaches the cancellation branch that shutdown has already
        armed.
        """
        termination_sent = termination_requested
        kill_deadline = (
            time.monotonic() + TERMINATION_GRACE_SECONDS
            if termination_requested
            else None
        )
        leader_status = None
        while True:
            if leader_status is None:
                try:
                    waited_pid, status = os.waitpid(child_pid, os.WNOHANG)
                except ChildProcessError:
                    leader_status = signal.SIGKILL
                else:
                    if waited_pid == child_pid:
                        leader_status = status
            live_members = live_process_group_members(child_pid)
            if leader_status is not None and live_members == []:
                return leader_status, termination_sent
            now = time.monotonic()
            if not termination_sent and now >= runtime_deadline:
                termination_sent = True
                kill_deadline = now + TERMINATION_GRACE_SECONDS
                self.signal_child(child_pid)
            elif termination_sent and now >= kill_deadline:
                with contextlib.suppress(ProcessLookupError, PermissionError):
                    os.killpg(child_pid, signal.SIGKILL)
                kill_deadline = now + TERMINATION_GRACE_SECONDS
            time.sleep(0.05)

    def finish_artifact(
        self,
        request,
        profile,
        job_id,
        part_path,
        started_at,
        started_monotonic,
        deadline,
        outcome,
    ):
        """Validate, hash, and name what the runtime wrote.

        The `.part.png` file is read whole and checked against the requested
        geometry before it acquires a name, so the artifact directory holds
        validated images alone and a reader of `<sha256>.png` needs no second
        opinion about what it holds. The rename is atomic within the directory
        and the provenance record follows the same write-then-rename path.
        """
        require_deadline(deadline, "artifact inspection")
        try:
            size = os.path.getsize(part_path)
        except OSError:
            raise PngInvalid(
                "the runtime exited successfully and wrote no file", "absent"
            ) from None
        if size == 0:
            raise PngInvalid("the runtime wrote an empty file", "absent")
        if size > ARTIFACT_BYTE_CAP:
            raise PngInvalid(
                f"the produced file is {size} bytes, above the "
                f"{ARTIFACT_BYTE_CAP} byte cap",
                "oversized",
            )
        with open(part_path, "rb") as handle:
            raw = handle.read(ARTIFACT_BYTE_CAP + 1)
        require_deadline(deadline, "artifact read")
        header = parse_png(raw, request["width"], request["height"])
        png_sha256 = hashlib.sha256(raw).hexdigest()
        artifact_path = os.path.join(self.artifact_directory, f"{png_sha256}.png")
        completed_at = time.time()
        provenance = self.build_provenance(
            request,
            profile,
            job_id,
            outcome,
            header,
            png_sha256,
            len(raw),
            started_at,
            completed_at,
        )
        provenance_body = (
            json.dumps(provenance, indent=2, sort_keys=True).encode("utf-8") + b"\n"
        )
        provenance_sha256 = hashlib.sha256(provenance_body).hexdigest()
        provenance_path = os.path.join(
            self.artifact_directory, f"{provenance_sha256}.json"
        )
        provenance_part = os.path.join(
            self.artifact_directory, f"{job_id}.provenance.part"
        )
        publication_path = os.path.join(
            self.artifact_directory, f".publication-{job_id}.json"
        )
        publication_part = f"{publication_path}.part"
        publication_body = json.dumps(
            {
                "schema": "qwen-image-publication/1",
                "job_id": job_id,
                "png_sha256": png_sha256,
                "provenance_sha256": provenance_sha256,
            },
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8") + b"\n"
        artifact_created = False
        provenance_created = False
        publication_created = False
        try:
            require_deadline(deadline, "provenance serialization")
            write_private_bytes(provenance_part, provenance_body)
            require_deadline(deadline, "provenance staging")
            os.chmod(part_path, 0o600)
            try:
                os.link(part_path, artifact_path)
                artifact_created = True
            except FileExistsError:
                with open(artifact_path, "rb") as handle:
                    if handle.read(ARTIFACT_BYTE_CAP + 1) != raw:
                        raise InternalFailure(
                            "an existing content-addressed PNG has different bytes"
                        ) from None
            require_deadline(deadline, "PNG publication")
            try:
                os.link(provenance_part, provenance_path)
                provenance_created = True
            except FileExistsError:
                with open(provenance_path, "rb") as handle:
                    if handle.read(ARTIFACT_BYTE_CAP + 1) != provenance_body:
                        raise InternalFailure(
                            "an existing content-addressed provenance has different bytes"
                        ) from None
            require_deadline(deadline, "provenance publication")
            write_private_bytes(publication_part, publication_body)
            require_deadline(deadline, "paired publication")
            os.replace(publication_part, publication_path)
            publication_created = True
            fsync_directory(self.artifact_directory)
            require_deadline(deadline, "publication durability")
        except Exception:
            if not publication_created:
                if provenance_created:
                    with contextlib.suppress(OSError):
                        os.unlink(provenance_path)
                if artifact_created and not self.artifact_is_published(
                    png_sha256, "png"
                ):
                    with contextlib.suppress(OSError):
                        os.unlink(artifact_path)
            raise
        finally:
            for temporary_path in (provenance_part, publication_part):
                with contextlib.suppress(OSError):
                    os.unlink(temporary_path)
        ended_monotonic = time.monotonic()
        return {
            "status": "completed",
            "sha256": png_sha256,
            "provenance_url": self.provenance_url(provenance_sha256),
            "artifact_url": self.artifact_url(png_sha256),
            "job_id": job_id,
            "bytes": len(raw),
            "seconds": round(ended_monotonic - started_monotonic, 3),
        }

    @staticmethod
    def artifact_url(digest):
        """Return the route the artifact is read at, relative to the listener.

        The digest names the file, so both routes are derived from it rather
        than chosen by the service: a reader resolves the path against the
        artifact listener it already holds a credential for, and no absolute
        origin travels in a protocol line.
        """
        return f"/artifacts/{digest}.png"

    @staticmethod
    def provenance_url(digest):
        return f"/artifacts/{digest}.json"

    def build_provenance(
        self,
        request,
        profile,
        job_id,
        outcome,
        header,
        png_sha256,
        png_bytes,
        started_at,
        completed_at,
    ):
        """Return the retained record of one generation.

        Every field the service observes carries its measurement; every field
        only the runtime or the kernel reports carries `-`, so a reader
        separates an absent measurement from a zero one. The prompts appear as
        digests rather than as text, which binds a record to the approval that
        authorized it and keeps the record free of the content it describes.
        """
        record = {
            "schema": "qwen-image-provenance/1",
            "job_id": job_id,
            "recorded_at": utc_timestamp(completed_at),
            "profile_id": profile["profile_id"],
            "model_id": profile["model_id"],
            "placement": profile["placement"],
            "execution_policy": profile["execution_policy"],
            "validated_evidence": profile.get("validated_evidence", UNOBSERVED),
            "prompt_sha256": sha256_text(request["prompt"]),
            "negative_prompt_sha256": sha256_text(request["negative_prompt"]),
            "authorization_sha256": (
                sha256_text(request["authorization"])
                if request["authorization"]
                else UNOBSERVED
            ),
            "seed": request["seed"],
            "width": request["width"],
            "height": request["height"],
            "aspect": request["aspect"],
            "steps": request["steps"],
            "sampler": profile["sampler"],
            "cfg": profile["cfg"],
            "color_type": header["color_type"],
            "bit_depth": header["bit_depth"],
            "png_sha256": png_sha256,
            "png_bytes": png_bytes,
            "runtime_path": profile["runtime_path"],
            "runtime_sha256": self.artifact_digest(profile["runtime_path"]),
            "runtime_argv": outcome["runtime_argv"],
            "runtime_pid": outcome["runtime_pid"],
            "priority_wrapper": outcome["priority_wrapper"],
            "priority_wrapper_sha256": outcome["priority_wrapper_sha256"],
            "model_path": profile.get("model_path", "") or UNOBSERVED,
            "model_sha256": profile.get("model_sha256", UNOBSERVED),
            "nice": outcome["nice"],
            "ioclass": outcome["ioclass"],
            "exit_status": outcome["exit_status"],
            "terminating_signal": outcome["terminating_signal"],
            "started_at": utc_timestamp(started_at),
            "runtime_seconds": outcome["runtime_seconds"],
            "total_seconds": round(completed_at - started_at, 3),
            "timeout_s_requested": outcome["timeout_s_requested"],
            "timeout_s_applied": outcome["timeout_s_applied"],
            "children_lifetime_maxrss_kib": outcome[
                "children_lifetime_maxrss_kib"
            ],
            "memavailable_minimum_kib": outcome["memavailable_minimum_kib"],
            "swap_delta_kib": outcome["swap_delta_kib"],
            "lease_path": self.lease.lock_path,
            "service_pid": os.getpid(),
        }
        # The runtime reports its own phase split, its PSS, and the device
        # counters through a channel this service does not read, and the kernel
        # reports ring resets, VM faults, and device loss to a log this service
        # does not parse. Each stays `-` rather than being inferred.
        for field in (
            "load_seconds",
            "text_encoder_seconds",
            "diffusion_seconds",
            "vae_seconds",
            "png_encode_seconds",
            "runtime_pss_kib",
            "ring_resets",
            "vm_faults",
            "device_loss",
            "desktop_graphics_latency_p90_ms",
        ):
            record[field] = UNOBSERVED
        record.update(self.settings.device_telemetry())
        return record

    @staticmethod
    def artifact_digest(path):
        try:
            return sha256_file(path)
        except OSError:
            return UNOBSERVED

    def handle_cancel(self, request_id):
        """End the generation the cancel names, or refuse as `not_running`.

        The protocol frame gives a cancel one identifier, so a cancel names its
        target by carrying the running generation's own `request_id`, which
        `status` reports as `job_request_id`. A cancel naming any other job
        answers `not_running` rather than ending the generation that happens to
        hold the device: one owner cancels one job, and a stale identifier from
        an earlier turn stops nothing.
        """
        with self.job.lock:
            active = self.job.phase != "idle"
            job_id = self.job.job_id
            job_request_id = self.job.request_id
            child_pid = self.job.child_pid
            owned = active and request_id == job_request_id
            if owned:
                self.job.cancel_requested = True
        if not active:
            raise NotRunning("no generation is running")
        if not owned:
            raise NotRunning(
                f"the cancel names {request_id!r} where the running generation "
                f"carries {job_request_id!r}"
            )
        if child_pid:
            self.signal_child(child_pid)
        return {"status": "accepted", "job_id": job_id, "cancelled": True}

    def handle_status(self):
        with self.job.lock:
            active = self.job.phase != "idle"
            payload = {
                "status": "accepted",
                "state": self.job.phase,
                "job_id": self.job.job_id if active else "",
                "job_request_id": self.job.request_id if active else "",
                "profile_id": self.job.profile_id if active else "",
                "started_at": utc_timestamp(self.job.started_at) if active else "",
                "elapsed_seconds": (
                    round(time.monotonic() - self.job.started_monotonic, 3)
                    if active
                    else 0
                ),
                "cancel_requested": self.job.cancel_requested if active else False,
                "lease_held": self.lease.held,
            }
        payload["lease_path"] = self.lease.lock_path
        payload["artifact_directory"] = self.artifact_directory
        payload["pid"] = os.getpid()
        return payload

    def dispatch(self, payload):
        """Route one control line to its action under the protocol contract.

        The frame check runs here for every action, so a control message meets
        the same closed schema a generation does: `cancel` and `status` name a
        job and carry none of the fields that describe one.
        """
        try:
            protocol.validate_request(payload)
        except protocol.ProtocolError as breach:
            raise InvalidArgument(str(breach)) from None
        request_id = payload["request_id"]
        action = payload["action"]
        if action == ACTION_GENERATE:
            return self.handle_generate(payload, request_id)
        if action == ACTION_CANCEL:
            return self.handle_cancel(request_id)
        return self.handle_status()

    def begin_shutdown(self):
        """Prevent new jobs and request cancellation for the active job."""
        self.shutdown_event.set()
        with self.job.lock:
            self.job.cancel_requested = True
            child_pid = self.job.child_pid
        if child_pid:
            self.signal_child(child_pid)

    def shutdown_residue(self):
        """Remove what a job leaves behind and report what survives it.

        The three residues are a live child, a `.part.png` file, and a held
        lease. Each is proved from its own state rather than from the absence
        of the others: a child that ignored SIGTERM is killed and re-checked,
        every `.part.png` (and any `.part` a prior version left, since a
        directory this proof runs against outlives the service that wrote to
        it) under the artifact directory is removed, and the lease closes
        with the descriptor.
        """
        self.begin_shutdown()
        # The child is signalled and escalated ahead of the quiescence
        # barrier: a handler wedged waiting on that child -- the D-state
        # Vulkan hang the kernel-hazard watcher exists for -- holds job_lock
        # for the job's whole duration, so an escalation placed behind the
        # lock would sit behind the very process it exists to kill.
        with self.job.lock:
            child_pid = self.job.child_pid
        if child_pid:
            self.signal_child(child_pid)
            deadline = time.monotonic() + TERMINATION_GRACE_SECONDS
            reaped = False
            while time.monotonic() < deadline:
                try:
                    waited, _ = os.waitpid(child_pid, os.WNOHANG)
                except ChildProcessError:
                    reaped = True
                    break
                if waited == child_pid:
                    reaped = True
                    break
                time.sleep(0.05)
            if not reaped:
                with contextlib.suppress(ProcessLookupError, PermissionError):
                    os.killpg(child_pid, signal.SIGKILL)
                with contextlib.suppress(ChildProcessError):
                    os.waitpid(child_pid, 0)
        # A generation owns job_lock from admission through its runtime and
        # final artifact action. Waiting on it after the kill forms the
        # quiescence barrier: an active handler observes cancellation and its
        # dead child, and a newly accepted handler refuses before creating
        # state. The wait is bounded so a handler that still fails to release
        # is reported as residue rather than hanging the teardown proof.
        job_lock_acquired = self.job_lock.acquire(timeout=TERMINATION_GRACE_SECONDS)
        try:
            surviving_child = 0
            if child_pid:
                try:
                    os.kill(child_pid, 0)
                    surviving_child = child_pid
                except OSError:
                    surviving_child = 0
            remaining_parts = []
            with contextlib.suppress(OSError):
                for name in sorted(os.listdir(self.artifact_directory)):
                    if name.endswith(".part.png") or name.endswith(".part"):
                        path = os.path.join(self.artifact_directory, name)
                        with contextlib.suppress(OSError):
                            os.unlink(path)
                        if os.path.lexists(path):
                            remaining_parts.append(name)
            self.lease.release()
            return {
                "child": surviving_child,
                "part_files": remaining_parts,
                "lease_held": self.lease.held,
                "job_lock_released": job_lock_acquired,
            }
        finally:
            if job_lock_acquired:
                self.job_lock.release()


class ControlHandler(socketserver.StreamRequestHandler):
    """Answer one JSON-line control request per connection.

    One request per connection keeps a long generation from blocking a `status`
    or `cancel` that arrives while it runs: the threading server takes those on
    their own connections, and the job lock rather than the socket is what
    serializes generation.
    """

    timeout = CONTROL_READ_TIMEOUT_SECONDS

    def handle(self):
        service = self.server.image_service
        request_id = ""
        try:
            line = self.rfile.readline(CONTROL_LINE_BYTE_CAP + 1)
        except OSError:
            return
        if not line:
            return
        try:
            payload = protocol.decode_line(line)
        except protocol.ProtocolError as breach:
            self.refuse(request_id, "invalid_argument", str(breach))
            return
        # The identifier is echoed on every reply, so it is read before the
        # frame check and held to the protocol's own identifier rule; a line
        # naming something outside that rule answers under UNIDENTIFIED_REQUEST
        # rather than putting the sender's bytes back on the wire.
        if isinstance(payload, dict) and isinstance(payload.get("request_id"), str):
            candidate = payload["request_id"]
            if (
                0 < len(candidate) <= protocol.MAX_IDENTIFIER_CHARACTERS
                and set(candidate) <= protocol.IDENTIFIER_CHARACTERS
            ):
                request_id = candidate
        try:
            self.reply(request_id, service.dispatch(payload))
        except ServiceError as error:
            detail = {"png_detail": error.detail} if isinstance(error, PngInvalid) else {}
            self.refuse(request_id, error.reason, str(error), error.status, detail)
        except Exception as error:  # noqa: BLE001 -- one request never ends the service
            self.refuse(
                request_id,
                "internal_error",
                f"{type(error).__name__}: {error}",
                "failed",
            )

    def refuse(self, request_id, reason, message, status="refused", extra=None):
        payload = {"status": status, "reason": reason, "error": message}
        if extra:
            payload.update(extra)
        self.reply(request_id, payload)

    def reply(self, request_id, payload):
        """Write one response line the protocol module validates before it goes.

        A field is present where it carries a value and absent otherwise: a
        JSON null in `error` reads as a stated failure to a strict reader, and
        `image_protocol.validate_response` refuses the key on a completed run
        for that reason. A cancellation reports its term through `reason`,
        which is what a reader routes on.
        """
        response = {
            "protocol_version": PROTOCOL_VERSION,
            "request_id": request_id or UNIDENTIFIED_REQUEST,
            "status": payload.get("status", "accepted"),
        }
        for key, value in payload.items():
            if key != "status" and value is not None:
                response[key] = value
        if response["status"] in ("accepted", "cancelled"):
            for key in ("sha256", "provenance_url", "error"):
                response.pop(key, None)
        try:
            protocol.validate_response(response, control_reply=True)
        except protocol.ProtocolError as breach:
            # A reply this service cannot state under its own protocol is a
            # defect in this service, so the peer reads a refusal naming it
            # rather than a line the checker on the other side rejects.
            response = {
                "protocol_version": PROTOCOL_VERSION,
                "request_id": request_id or UNIDENTIFIED_REQUEST,
                "status": "failed",
                "reason": "internal_error",
                "error": f"the service composed a reply outside its protocol: {breach}",
            }
        with contextlib.suppress(OSError):
            self.wfile.write(protocol.encode_line(response).encode("utf-8"))
            self.wfile.flush()


class ControlServer(socketserver.ThreadingUnixStreamServer):
    allow_reuse_address = False
    daemon_threads = True
    block_on_close = False

    def __init__(self, path, image_service):
        self.image_service = image_service
        super().__init__(path, ControlHandler)


class ArtifactHandler(http.server.BaseHTTPRequestHandler):
    """Serve health and completed immutable artifacts to a credentialed reader."""

    protocol_version = "HTTP/1.1"
    server_version = "qwen-image-artifacts/1.0"
    sys_version = ""
    # `socketserver.StreamRequestHandler.setup` applies this to the accepted
    # socket, and `BaseHTTPRequestHandler.handle_one_request` already catches
    # the resulting `socket.timeout` and closes the connection. Under the
    # wildcard listener an unauthenticated peer that sends a partial request,
    # or that holds an HTTP/1.1 connection open past a 401, is dropped after
    # this many idle seconds rather than parking its thread indefinitely.
    timeout = ARTIFACT_READ_TIMEOUT_SECONDS

    def log_message(self, fmt, *args):
        """Drop the default access log; the provenance record is the trail."""

    @property
    def settings(self):
        return self.server.image_settings

    def allowed_origin(self):
        """Return the request Origin when the launch admits it, or an empty string.

        The configured origins are echoed back exactly, so a wildcard never
        reaches a response and a page outside the list reads no artifact. The
        list holds the exposure literal's page origin and the exposure name's,
        because one appliance page is reachable at either host.
        """
        origin = self.headers.get("Origin", "")
        return origin if origin and origin in self.settings.origins else ""

    def send_json(self, http_status, payload, origin=""):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(http_status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_cors_headers(origin)
        self.end_headers()
        self.wfile.write(body)

    def send_cors_headers(self, origin):
        if origin:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")

    def authorized(self):
        """Return whether the request carries the Web UI bearer API key.

        The fallback Web UI sends `Authorization: Bearer <key>` on every
        request it makes, so an artifact reaches the page through the header it
        already holds. The comparison runs in constant time and precedes every
        lookup below; a query parameter carries no authority at all. Under
        `--open-lan` the launch read no key, so the comparison would stand
        against an empty expectation and the check returns admitted instead:
        the Host set and the Origin allowlist are what remain.
        """
        if self.settings.open_lan:
            return True
        presented = self.headers.get("Authorization", "")
        expected = f"Bearer {self.settings.api_key}"
        return bool(presented) and hmac.compare_digest(presented, expected)

    def do_OPTIONS(self):  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        """Answer the preflight the Authorization header forces on a browser."""
        origin = self.allowed_origin()
        self.send_response(204 if origin else 403)
        self.send_header("Content-Length", "0")
        if origin:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Authorization")
            self.send_header("Access-Control-Max-Age", "60")
            self.send_header("Vary", "Origin")
        self.end_headers()

    def do_GET(self):  # noqa: N802 -- BaseHTTPRequestHandler names the verb
        """Answer health and artifact reads, credential first.

        The bearer check runs ahead of the artifact lookup, so a present hash
        and an absent one answer 401 alike to an unauthenticated reader: the
        hash identifies an artifact and never authenticates one, and a
        404-against-401 split would turn the route into an existence oracle.
        """
        origin = self.allowed_origin()
        if not host_header_names(
            self.headers.get("Host", ""), self.settings.admitted_hosts
        ):
            self.send_json(
                403,
                {
                    "error": "the request Host names no admitted literal: "
                    + ", ".join(self.settings.admitted_hosts)
                },
            )
            return
        if not self.authorized():
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Bearer realm="qwen-image"')
            self.send_header("Content-Length", "0")
            self.send_header("Cache-Control", "no-store")
            self.send_cors_headers(origin)
            self.end_headers()
            return
        path = self.path.split("?", 1)[0]
        if path == "/health":
            service = self.server.image_service
            status = service.handle_status()
            self.send_json(
                200,
                {
                    "protocol": "qwen-image-service/1",
                    "protocol_version": PROTOCOL_VERSION,
                    "pid": os.getpid(),
                    "state": status["state"],
                    "lease_held": status["lease_held"],
                    "artifact_directory": service.artifact_directory,
                },
                origin,
            )
            return
        prefix = "/artifacts/"
        if not path.startswith(prefix):
            self.send_json(404, {"error": "no such endpoint"}, origin)
            return
        match = ARTIFACT_NAME_PATTERN.match(path[len(prefix) :])
        if match is None:
            # The name is the content digest and a suffix, so traversal,
            # relative components, and every other spelling of a path are
            # refused by the pattern rather than by a normalisation pass.
            self.send_json(
                404, {"error": "an artifact is named <sha256>.png or <sha256>.json"}, origin
            )
            return
        self.send_artifact(match.group(1), match.group(2), origin)

    def send_artifact(self, digest, suffix, origin):
        service = self.server.image_service
        directory = service.artifact_directory
        if not service.artifact_is_published(digest, suffix):
            self.send_json(404, {"error": "no such artifact"}, origin)
            return
        path = os.path.join(directory, f"{digest}.{suffix}")
        try:
            with open(path, "rb") as handle:
                body = handle.read(ARTIFACT_BYTE_CAP + 1)
        except OSError:
            self.send_json(404, {"error": "no such artifact"}, origin)
            return
        content_type = "image/png" if suffix == "png" else "application/json"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        # The artifact is named by the SHA-256 of its own bytes, so the content
        # at one URL never changes and the response says so. `private` rather
        # than `public` because the response is credentialed and this listener
        # serves one user over loopback.
        self.send_header("Cache-Control", "private, max-age=31536000, immutable")
        self.send_header("ETag", f'"{digest}"')
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Disposition", f'inline; filename="{digest}.{suffix}"')
        self.send_cors_headers(origin)
        self.end_headers()
        self.wfile.write(body)


ARTIFACT_CONNECTION_LIMIT_RESPONSE = (
    b"HTTP/1.1 503 Service Unavailable\r\n"
    b"Connection: close\r\n"
    b"Content-Length: 0\r\n"
    b"\r\n"
)


class ArtifactServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = False
    daemon_threads = True
    block_on_close = False

    def __init__(self, address, settings, image_service):
        self.address_family = socket.AF_INET6 if ":" in address[0] else socket.AF_INET
        self.image_settings = settings
        self.image_service = image_service
        # `ThreadingMixIn.process_request` spawns a thread on every accepted
        # connection before the Host or bearer checks run, so a wildcard bind
        # lets an unauthenticated peer that holds many connections open
        # exhaust threads ahead of any credential. This semaphore bounds the
        # resident handler count independently of that check ordering.
        self._connection_semaphore = threading.BoundedSemaphore(
            ARTIFACT_MAX_CONCURRENT_CONNECTIONS
        )
        super().__init__(address, ArtifactHandler)

    def process_request(self, request, client_address):
        """Refuse a connection past the concurrent cap rather than spawn for it."""
        if not self._connection_semaphore.acquire(blocking=False):
            with contextlib.suppress(OSError):
                request.sendall(ARTIFACT_CONNECTION_LIMIT_RESPONSE)
            with contextlib.suppress(OSError):
                request.shutdown(socket.SHUT_RDWR)
            request.close()
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self._connection_semaphore.release()
            raise

    def process_request_thread(self, request, client_address):
        """Release the cap slot this connection's thread acquired, on every exit."""
        try:
            super().process_request_thread(request, client_address)
        finally:
            self._connection_semaphore.release()


class ServiceSettings:
    """What one launch serves, spawns, and admits."""

    def __init__(self, arguments, verifier, api_key):
        self.state_directory = arguments.state_dir
        self.image_directory = os.path.join(arguments.state_dir, IMAGE_DIRECTORY_NAME)
        self.verifier = verifier
        self.api_key = api_key
        # A page reachable at two hosts sends two Origins, so the allowlist is
        # a tuple and `allowed_origin` echoes back the one entry it matched.
        self.origins = tuple(arguments.origin)
        # The exposure literal widens the Host-header set by exactly one entry
        # and the exposure name by one more. The bearer already gates every
        # route this listener serves, so the credential the page holds is the
        # credential a LAN reader presents, and `--open-lan` is the operator's
        # decision to serve the artifact routes without one.
        self.exposure = arguments.lan_exposure
        self.exposure_name = arguments.lan_name
        self.open_lan = arguments.open_lan
        self.admitted_hosts = admitted_hosts(
            arguments.lan_exposure, arguments.lan_name
        )
        self.runtime_environment = dict(
            entry.split("=", 1) for entry in arguments.runtime_env
        )
        # The RADV ICD pin wins over any conflicting --runtime-env entry,
        # the way remote/radv-icd-env.sh's export always sets the pair
        # rather than leaving it to the caller to remember; a caller may
        # still steer the derivation itself through QWEN_RADV_ICD.
        self.runtime_environment.update(derive_radv_icd_environment())
        self.priority_wrapper = os.path.realpath(arguments.priority_wrapper)
        if not os.path.isfile(self.priority_wrapper) or not os.access(
            self.priority_wrapper, os.X_OK
        ):
            raise ServiceError(
                f"the priority wrapper is not executable: {self.priority_wrapper}"
            )
        self.priority_wrapper_sha256 = sha256_file(self.priority_wrapper)

    @staticmethod
    def device_telemetry():
        """Return the amdgpu counters this host exposes, and `-` for the rest.

        The appliance publishes VRAM and GTT use and busy percent under the
        card's sysfs directory; a workstation running the tests publishes none
        of them, so each field reports its own absence rather than a zero that
        reads as a measurement. Die temperature lives under a hwmon node whose
        index varies, and it stays `-` here rather than being guessed.
        """
        readings = {
            "vram_used_bytes": UNOBSERVED,
            "gtt_used_bytes": UNOBSERVED,
            "gpu_busy_percent": UNOBSERVED,
            "gpu_temperature_millicelsius": UNOBSERVED,
        }
        sources = {
            "vram_used_bytes": "mem_info_vram_used",
            "gtt_used_bytes": "mem_info_gtt_used",
            "gpu_busy_percent": "gpu_busy_percent",
        }
        base = "/sys/class/drm"
        try:
            cards = sorted(
                name for name in os.listdir(base) if re.fullmatch(r"card\d+", name)
            )
        except OSError:
            return readings
        for card in cards:
            device = os.path.join(base, card, "device")
            for field, leaf in sources.items():
                if readings[field] != UNOBSERVED:
                    continue
                try:
                    with open(os.path.join(device, leaf), encoding="ascii") as handle:
                        readings[field] = int(handle.read().strip())
                except (OSError, ValueError):
                    continue
        return readings


def load_profiles(path):
    """Return the profile parameters the default verifier resolves against.

    The registry lane owns `remote/image-profiles.tsv` and this service reads
    no TSV: a caller resolves a row to a dictionary and names the file here, so
    a registry change reaches the service through its caller rather than
    through a second parser of the same table.
    """
    with open(path, encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise InvalidArgument("the profile file holds one object keyed by profile_id")
    for profile_id, profile in payload.items():
        validate_profile(profile)
        if profile["profile_id"] != profile_id:
            raise InvalidArgument(
                f"the profile under key {profile_id!r} names itself "
                f"{profile['profile_id']!r}"
            )
    return payload


def bind_control_socket(path):
    """Return a control server on a socket no other live service holds.

    A stale socket file survives a killed service and a live one belongs to a
    running service, so the two are separated by connecting: a refused
    connection proves the file is residue and it is unlinked, while a
    successful one leaves the running service alone. The socket is created
    under umask 0177 inside a 0700 directory, so its mode is right at the
    moment it exists rather than after a chmod.
    """
    if os.path.lexists(path):
        probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        probe.settimeout(1.0)
        try:
            probe.connect(path)
        except OSError as error:
            if error.errno not in (errno.ECONNREFUSED, errno.ENOENT):
                raise
            os.unlink(path)
        else:
            raise InvalidArgument(
                f"another image service answers on {path}; one service owns "
                "the control socket"
            )
        finally:
            probe.close()
    previous_umask = os.umask(0o177)
    try:
        return ControlServer(path, None)
    finally:
        os.umask(previous_umask)


def build_parser():
    parser = argparse.ArgumentParser(
        prog="image-service.py",
        description="serve one owned image generation at a time behind the "
        "Vulkan workload lease; the control socket takes image_generate, "
        "cancel, and status as JSON lines, and the loopback HTTP listener "
        "serves completed artifacts to a caller presenting the Web UI bearer "
        "API key",
    )
    parser.add_argument(
        "--state-dir",
        default=os.environ.get(
            "QWEN_WEBUI_STATE_DIRECTORY",
            os.path.join(os.environ.get("HOME", ""), "qwen-webui-state"),
        ),
    )
    parser.add_argument(
        "--profiles-json",
        default=os.environ.get("QWEN_IMAGE_PROFILES_JSON", ""),
        help="a file of validated profile parameters keyed by profile_id, "
        "which the default verifier resolves a request against",
    )
    parser.add_argument(
        "--verifier",
        default=os.environ.get("QWEN_IMAGE_VERIFIER", ""),
        help="MODULE:FUNCTION implementing verify(request) -> profile parameters",
    )
    parser.add_argument(
        "--api-key-file", default=os.environ.get("QWEN_WEBUI_API_KEY_FILE", "")
    )
    parser.add_argument(
        "--origin",
        action="append",
        default=None,
        help="one page origin the artifact routes admit through CORS; repeat "
        "it for a page reachable at both the exposure literal and the "
        "exposure name",
    )
    parser.add_argument(
        "--priority-wrapper",
        default=os.environ.get("QWEN_IMAGE_PRIORITY_WRAPPER", DEFAULT_PRIORITY_WRAPPER),
        help="the executable that places the runtime at nice 19 and the idle "
        "I/O class before exec; defaults to qwen-exec-idle-priority.sh beside "
        "this file",
    )
    parser.add_argument("--http-host", type=loopback_host, default="127.0.0.1")
    parser.add_argument(
        "--lan-exposure", type=exposed_host, default="",
        help="the routable IPv4 literal this listener admits in a Host header "
        "beside the loopback ones; the Web UI bearer already gates every route",
    )
    parser.add_argument(
        "--lan-name", type=exposed_name, default="",
        help="the mDNS hostname this listener admits in a Host header beside "
        "the exposure literal, compared casefolded",
    )
    parser.add_argument(
        "--open-lan", action="store_true",
        help="serve the artifact routes without the Web UI bearer, leaving the "
        "admitted Host set and the Origin allowlist as the gate; requires "
        "--lan-exposure",
    )
    parser.add_argument("--http-port", type=int, default=0)
    parser.add_argument(
        "--runtime-env",
        action="append",
        default=[],
        metavar="NAME=VALUE",
        help="one environment entry the runtime receives beside PATH and HOME",
    )
    return parser


def run(argv):
    """Serve until a terminating signal, then prove what the job left behind."""
    arguments = build_parser().parse_args(argv)
    # The listener decision comes first, ahead of every profile and credential
    # check, because a caller who widened the bind by itself is refused on that
    # ground rather than on whichever input it happened to omit as well.
    if arguments.http_host == WILDCARD_HOST and not arguments.lan_exposure:
        sys.stderr.write(
            f"--http-host {WILDCARD_HOST} serves the network, so --lan-exposure "
            "names the routable literal the Host header is gated on\n"
        )
        return 2
    # The name widens the exposed Host set and the open opt-in removes a
    # credential from an exposed listener, so each names the exposure it
    # belongs to rather than standing on its own.
    if arguments.lan_name and not arguments.lan_exposure:
        sys.stderr.write(
            "--lan-name adds a Host to the exposed set, so --lan-exposure "
            "names the literal that set is built from\n"
        )
        return 2
    if arguments.open_lan and not arguments.lan_exposure:
        sys.stderr.write(
            "--open-lan removes the Web UI bearer from an exposed listener, "
            "so --lan-exposure names the address it exposes\n"
        )
        return 2
    if arguments.origin is None:
        configured = os.environ.get("QWEN_IMAGE_PAGE_ORIGIN", "")
        arguments.origin = [entry for entry in configured.split(",") if entry]
    if not arguments.state_dir:
        sys.stderr.write(
            "the service keeps its lease, socket, and artifacts under one "
            "directory, so QWEN_WEBUI_STATE_DIRECTORY or --state-dir names it\n"
        )
        return 2
    if not arguments.profiles_json and not arguments.verifier:
        sys.stderr.write(
            "the service reads no registry, so --profiles-json names the "
            "validated profile parameters its caller resolved, or --verifier "
            "names the callable that returns them\n"
        )
        return 2
    for entry in arguments.runtime_env:
        if "=" not in entry:
            sys.stderr.write(f"--runtime-env takes NAME=VALUE; {entry!r} carries no =\n")
            return 2
    try:
        ArtifactHandler.timeout = artifact_read_timeout_seconds_from_environment()
    except ServiceError as error:
        sys.stderr.write(f"the artifact listener's read timeout is unusable: {error}\n")
        return 2
    profiles = {}
    if arguments.profiles_json:
        try:
            profiles = load_profiles(arguments.profiles_json)
        except (OSError, ValueError, ServiceError) as error:
            sys.stderr.write(f"the profile parameters are unusable: {error}\n")
            return 2
    if arguments.verifier:
        try:
            verifier = load_verifier(arguments.verifier)
        except (argparse.ArgumentTypeError, ImportError) as error:
            sys.stderr.write(f"the signed-request verifier is unusable: {error}\n")
            return 2
    else:
        verifier = shape_only_verifier(profiles)
    # The open opt-in reads no key file, because the bearer it would compare
    # against is the one it removes and `read_secret_file` refuses an
    # unconfigured path: a launch serving without a key hands this process an
    # empty `--api-key-file` and would otherwise exit here.
    api_key = ""
    if not arguments.open_lan:
        try:
            api_key = read_secret_file(arguments.api_key_file, "Web UI API")
        except ServiceError as error:
            sys.stderr.write(f"the service cannot read the Web UI API key: {error}\n")
            return 2
    os.makedirs(arguments.state_dir, mode=PRIVATE_DIRECTORY_MODE, exist_ok=True)
    image_directory = os.path.join(arguments.state_dir, IMAGE_DIRECTORY_NAME)
    os.makedirs(image_directory, mode=PRIVATE_DIRECTORY_MODE, exist_ok=True)
    try:
        settings = ServiceSettings(arguments, verifier, api_key)
    except ServiceError as error:
        sys.stderr.write(f"the runtime environment is unusable: {error}\n")
        return 2
    service = ImageService(settings)
    socket_path = os.path.join(image_directory, SOCKET_FILE_NAME)
    try:
        control = bind_control_socket(socket_path)
    except (OSError, ServiceError) as error:
        sys.stderr.write(f"the control socket is unavailable: {error}\n")
        return 2
    control.image_service = service
    artifacts = ArtifactServer(
        (arguments.http_host, arguments.http_port), settings, service
    )
    http_port = artifacts.server_address[1]
    pid_path = os.path.join(image_directory, PID_FILE_NAME)
    with open(pid_path, "w", encoding="ascii") as handle:
        handle.write(f"{os.getpid()}\n")
    # The caller reads the two addresses rather than guessing them, because an
    # ephemeral HTTP port is the default and the socket lives under a state
    # directory the launch chooses.
    sys.stdout.write(f"socket {socket_path}\n")
    sys.stdout.write(f"listening {arguments.http_host} {http_port}\n")
    sys.stdout.write(f"pid {os.getpid()}\n")
    sys.stdout.flush()

    shutdown_requested = False

    def raise_interrupt(number, frame):
        nonlocal shutdown_requested
        if shutdown_requested:
            return
        shutdown_requested = True
        raise KeyboardInterrupt(f"signal {number}")

    for terminating_signal in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(terminating_signal, raise_interrupt)
    http_thread = threading.Thread(target=artifacts.serve_forever, daemon=True)
    http_thread.start()
    try:
        control.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        # A control-server return enters the same teardown path without a
        # signal.  Mark that transition before any blocking shutdown call so a
        # later HUP, INT, or TERM cannot interrupt child and lease cleanup.
        shutdown_requested = True
        service.begin_shutdown()
        artifacts.shutdown()
        artifacts.server_close()
        control.server_close()
        residue = service.shutdown_residue()
        with contextlib.suppress(OSError):
            os.unlink(socket_path)
        with contextlib.suppress(OSError):
            os.unlink(pid_path)
        sys.stdout.write(
            "shutdown child={} part_files={} lease={} socket={}\n".format(
                residue["child"] or "absent",
                len(residue["part_files"]),
                "held" if residue["lease_held"] else "released",
                "present" if os.path.lexists(socket_path) else "removed",
            )
        )
        sys.stdout.flush()
    if residue["child"] or residue["part_files"] or residue["lease_held"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(run(sys.argv[1:]))
