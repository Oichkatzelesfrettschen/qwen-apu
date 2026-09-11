"""The Vulkan submission environment remote/radv-low-priority-env.sh hands the server.

`profile_environment` is that script's environment transform: it copies six
caller-supplied values aside, removes the closed scrub list, exports the four
constants every profile shares, applies the named profile's own exports, and
then applies the three `QWEN_` names that cross the scrub under their own
spelling. The result is the complete environment the next link execs with, so
a name the scrub removed is absent from the returned mapping rather than
present and empty -- an unset has no other representation in a `dict[str, str]`.

The scrub is a closed list of fifty-five names rather than a `GGML_VK_*`
wildcard. `GGML_VK_LOW_PRIORITY` sits outside it and is exported to `1`
immediately afterwards, so its ambient value never reaches the server either;
any other `GGML_VK_` name the list omits survives untouched.

Environment variables this module reads, under the shell's own names:

    QWEN_RADV_ICD                   ICD manifest, default
                                    /usr/share/vulkan/icd.d/radeon_icd.x86_64.json
    QWEN_VULKAN_PROFILE             profile name, default low-serialized
    QWEN_PERF_LOGGER                diagnostic frequency, required by that
                                    profile and refused by the four serving ones
    QWEN_PIPELINE_CENSUS            re-exported as GGML_VK_PIPELINE_CENSUS
    QWEN_Q4K_VARIANT                re-exported as GGML_VK_Q4K_VARIANT
    QWEN_FORCE_INTEGER_DOT          re-exported as GGML_VK_FORCE_INTEGER_DOT
    GGML_VK_MAX_NODES_PER_SUBMIT    captured ahead of the scrub for `custom`
    GGML_VK_SERIALIZE_SUBMISSIONS   captured ahead of the scrub for `custom`
    GGML_VK_ALLOW_GRAPHICS_QUEUE    captured ahead of the scrub for `custom`
    GGML_VK_SUBMIT_TRACE            captured ahead of the scrub for `custom`
    GGML_VK_FORCE_INTEGER_DOT       captured ahead of the scrub for `diagnostic`
    QWEN_INFERENCE_CPU              the core `taskset` pins, read by the process
                                    layer rather than by this transform

Three actions of the shell script sit outside this function. `renice -n 19`,
`taskset -pc "$QWEN_INFERENCE_CPU"`, and `ionice -c 3` change the calling
process rather than its environment and belong to the process layer;
`require_radv_icd` carries the ICD readability refusal, and
`profile_environment` runs it by default so the ordinary call reproduces the
shell's own exit-1 path.
"""

from __future__ import annotations

import os
from collections.abc import Mapping

DEFAULT_RADV_ICD = "/usr/share/vulkan/icd.d/radeon_icd.x86_64.json"  # appliance-path: named
DEFAULT_PROFILE = "low-serialized"

SERVING_PROFILES: tuple[str, ...] = ("paced-60", "low-serialized", "low-async", "custom")
PROFILES: tuple[str, ...] = (*SERVING_PROFILES, "diagnostic")

Q4K_VARIANT_VALUES: frozenset[str] = frozenset(
    ["production/4"]
    + [
        f"{family}/{width}"
        for family in ("e4", "e4-scale", "e4-scale-licm")
        for width in ("2", "4", "8")
    ]
)

# The names the script captures before the scrub runs, so `custom` and
# `diagnostic` can restore what the caller asked for.
CAPTURED_NAMES: tuple[str, ...] = (
    "GGML_VK_MAX_NODES_PER_SUBMIT",
    "GGML_VK_SERIALIZE_SUBMISSIONS",
    "GGML_VK_ALLOW_GRAPHICS_QUEUE",
    "GGML_VK_SUBMIT_TRACE",
    "GGML_VK_FORCE_INTEGER_DOT",
    "QWEN_PERF_LOGGER",
)

SCRUBBED_NAMES: tuple[str, ...] = (
    "DISPLAY",
    "WAYLAND_DISPLAY",
    "QWEN_ONE_CORE_ACTIVE",
    "QWEN_GUARD_CPU_ACTIVE",
    "AMD_PRIORITY",
    "AMD_DEBUG",
    "DRI_PRIME",
    "MESA_VK_DEVICE_SELECT",
    "RADV_DEBUG",
    "RADV_PERFTEST",
    "VK_ADD_LAYER_PATH",
    "VK_INSTANCE_LAYERS",
    "VK_LAYER_PATH",
    "VK_LOADER_LAYERS_ENABLE",
    "GGML_VK_ALLOW_GRAPHICS_QUEUE",
    "GGML_VK_ALLOW_SYSMEM_FALLBACK",
    "GGML_VK_ASYNC_USE_TRANSFER_QUEUE",
    "GGML_VK_DEBUG_MARKERS",
    "GGML_VK_DISABLE_ASYNC",
    "GGML_VK_DISABLE_BFLOAT16",
    "GGML_VK_DISABLE_COOPMAT",
    "GGML_VK_DISABLE_COOPMAT2",
    "GGML_VK_DISABLE_COOPMAT2_DECODE_VECTOR",
    "GGML_VK_DISABLE_DOT2",
    "GGML_VK_DISABLE_F16",
    "GGML_VK_DISABLE_FUSION",
    "GGML_VK_DISABLE_GRAPH_OPTIMIZE",
    "GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM",
    "GGML_VK_DISABLE_INTEGER_DOT_PRODUCT",
    "GGML_VK_DISABLE_MMVQ",
    "GGML_VK_DISABLE_MULTI_ADD",
    "GGML_VK_DISABLE_OCP_FP4",
    "GGML_VK_DUTY_CYCLE_PERCENT",
    "GGML_VK_ENABLE_MEMORY_PRIORITY",
    "GGML_VK_FORCE_INTEGER_DOT",
    "GGML_VK_FORCE_MAX_ALLOCATION_SIZE",
    "GGML_VK_FORCE_MAX_BUFFER_SIZE",
    "GGML_VK_FORCE_MMVQ",
    "GGML_VK_MEMORY_LOGGER",
    "GGML_VK_SERIALIZE_SUBMISSIONS",
    "GGML_VK_MAX_NODES_PER_SUBMIT",
    "GGML_VK_PERF_LOGGER",
    "GGML_VK_PERF_LOGGER_CONCURRENT",
    "GGML_VK_PERF_LOGGER_FREQUENCY",
    "GGML_VK_PIPELINE_STATS",
    "GGML_VK_PIPELINE_CENSUS",
    "GGML_VK_PIPELINE_CENSUS_DUMP",
    "GGML_VK_PREFER_HOST_MEMORY",
    "GGML_VK_Q4K_SIDEPLANE",
    "GGML_VK_Q4K_SIDEPLANE_LOG",
    "GGML_VK_Q4K_VARIANT",
    "GGML_VK_SUBALLOCATION_BLOCK_SIZE",
    "GGML_VK_SUBMIT_TRACE",
    "GGML_VK_SYNC_LOGGER",
    "GGML_VK_VISIBLE_DEVICES",
)


class ProfileError(RuntimeError):
    """A refusal remote/radv-low-priority-env.sh prints before it execs.

    `status` carries the exit code the shell leaves: 1 for the unreadable ICD
    and 2 for every input the profile case refuses.
    """

    def __init__(self, message: str, status: int = 2) -> None:
        super().__init__(message)
        self.status = status


def radv_icd(ambient: Mapping[str, str]) -> str:
    """The ICD manifest `VK_DRIVER_FILES` and `VK_ICD_FILENAMES` name."""
    value = ambient.get("QWEN_RADV_ICD", "")
    return value if value else DEFAULT_RADV_ICD


def require_radv_icd(ambient: Mapping[str, str]) -> str:
    """The ICD manifest, refused when the running user cannot read it."""
    path = radv_icd(ambient)
    if not os.access(path, os.R_OK):
        raise ProfileError(f"RADV ICD is not readable: {path}", status=1)
    return path


def _positive_decimal(value: str) -> bool:
    """The shell's `*[!0-9]* | '' | 0*` refusal read positively."""
    return value.isascii() and value.isdigit() and not value.startswith("0")


def profile_environment(
    profile: str, ambient: Mapping[str, str], *, check_icd: bool = True
) -> dict[str, str]:
    """The complete environment the profile hands the next link.

    `profile` is the resolved `QWEN_VULKAN_PROFILE`; an empty string reads as
    `low-serialized`, the default the shell's parameter expansion supplies.
    `check_icd` runs the readability refusal, which is what the shell does
    before its profile case; a caller measuring the transform alone clears it.
    """
    icd = require_radv_icd(ambient) if check_icd else radv_icd(ambient)

    requested = {name: ambient.get(name, "") for name in CAPTURED_NAMES}
    resulting = dict(ambient)
    for name in SCRUBBED_NAMES:
        resulting.pop(name, None)

    resulting["VK_DRIVER_FILES"] = icd
    resulting["VK_ICD_FILENAMES"] = icd
    resulting["GGML_VK_LOW_PRIORITY"] = "1"
    resulting["LLAMA_NO_CPU_FALLBACK"] = "1"

    resolved_profile = profile if profile else DEFAULT_PROFILE
    perf_logger = requested["QWEN_PERF_LOGGER"]
    if resolved_profile in SERVING_PROFILES and perf_logger:
        raise ProfileError("QWEN_PERF_LOGGER belongs to the diagnostic profile alone")

    if resolved_profile == "paced-60":
        resulting["GGML_VK_DUTY_CYCLE_PERCENT"] = "60"
        resulting["GGML_VK_SERIALIZE_SUBMISSIONS"] = "1"
        resulting["GGML_VK_MAX_NODES_PER_SUBMIT"] = "32"
    elif resolved_profile == "low-serialized":
        resulting["GGML_VK_SERIALIZE_SUBMISSIONS"] = "1"
        resulting["GGML_VK_MAX_NODES_PER_SUBMIT"] = "32"
    elif resolved_profile == "low-async":
        resulting["GGML_VK_MAX_NODES_PER_SUBMIT"] = "16"
    elif resolved_profile == "diagnostic":
        if not _positive_decimal(perf_logger):
            raise ProfileError(
                "the diagnostic profile requires QWEN_PERF_LOGGER as a positive "
                f"decimal frequency: {perf_logger}"
            )
        resulting["GGML_VK_SERIALIZE_SUBMISSIONS"] = "1"
        resulting["GGML_VK_MAX_NODES_PER_SUBMIT"] = "32"
        resulting["GGML_VK_PERF_LOGGER"] = "1"
        resulting["GGML_VK_PERF_LOGGER_FREQUENCY"] = perf_logger
        # Five names the scrub already removed, repeated so the profile reads
        # as one closed declaration rather than as a difference against it.
        for name in (
            "GGML_VK_PERF_LOGGER_CONCURRENT",
            "GGML_VK_PIPELINE_STATS",
            "GGML_VK_MEMORY_LOGGER",
            "GGML_VK_SUBMIT_TRACE",
            "RADV_DEBUG",
        ):
            resulting.pop(name, None)
        forced_dot = requested["GGML_VK_FORCE_INTEGER_DOT"]
        if forced_dot == "1":
            resulting["GGML_VK_FORCE_INTEGER_DOT"] = forced_dot
        elif forced_dot != "":
            raise ProfileError(
                f"GGML_VK_FORCE_INTEGER_DOT admits 1 or an unset value: {forced_dot}"
            )
    elif resolved_profile == "custom":
        # The named profiles fix both submission settings together, so `custom`
        # restores one at a time and a sweep attributes each separately.
        for name in (
            "GGML_VK_MAX_NODES_PER_SUBMIT",
            "GGML_VK_SERIALIZE_SUBMISSIONS",
            "GGML_VK_ALLOW_GRAPHICS_QUEUE",
            "GGML_VK_SUBMIT_TRACE",
        ):
            if requested[name]:
                resulting[name] = requested[name]
    else:
        raise ProfileError(f"unknown Vulkan profile: {resolved_profile}")

    resulting["QWEN_VULKAN_PROFILE"] = resolved_profile

    census = resulting.get("QWEN_PIPELINE_CENSUS", "")
    if census:
        resulting["GGML_VK_PIPELINE_CENSUS"] = census

    q4k_variant = resulting.get("QWEN_Q4K_VARIANT", "")
    if q4k_variant:
        if q4k_variant not in Q4K_VARIANT_VALUES:
            raise ProfileError(
                "QWEN_Q4K_VARIANT is production/4, or e4, e4-scale, or "
                f"e4-scale-licm over /2, /4, or /8: {q4k_variant}"
            )
        resulting["GGML_VK_Q4K_VARIANT"] = q4k_variant

    forced_dot_request = resulting.get("QWEN_FORCE_INTEGER_DOT", "")
    if forced_dot_request:
        if forced_dot_request != "1":
            raise ProfileError(
                f"QWEN_FORCE_INTEGER_DOT admits 1 or an unset value: {forced_dot_request}"
            )
        resulting["GGML_VK_FORCE_INTEGER_DOT"] = "1"

    return resulting
