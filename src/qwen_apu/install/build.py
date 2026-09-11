"""The optional source build: one CMake configure and one CMake build, as argv.

`remote/build-llama-vulkan.sh` holds the shell authority for the flags. It
proves `cmake`, `ninja`, `glslc`, `cc`, and `c++` present before it configures
anything and names the first absent one, because a configure that starts
without them fails deep inside CMake's own probing with a message about a
compiler rather than about a missing package. This module applies the same
gate through `shutil.which` and raises `ToolchainMissing` naming every absent
tool at once, since an operator installing them reads one list rather than one
name per rerun.

The prebuilt deployment bundle is the path that needs none of these tools, so
the refusal says so: a workstation without a toolchain installs the bundle and
a source build stays the optional path its evidence describes.

Two steps of the shell script sit outside `configure_and_build`'s signature
and this module models neither: the removal of a prior `tools/ui/dist` before
an incremental configure, and the SPIR-V C++ header check. The defines and
targets below match the script word for word, which
`tests/test_install_source.py` compares against the script's own text.
"""

from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

# The commands remote/build-llama-vulkan.sh proves present, in its own order.
REQUIRED_COMMANDS: tuple[str, ...] = ("cmake", "ninja", "glslc", "cc", "c++")

# The generator and the defines the script passes, in the script's order. GGML
# selects the Vulkan backend and leaves every other backend off, so the binary
# this produces carries the CPU and Vulkan backends alone.
GENERATOR = "Ninja"
VULKAN_DEFINES: dict[str, str] = {
    "CMAKE_BUILD_TYPE": "Release",
    "BUILD_SHARED_LIBS": "OFF",
    "LLAMA_FATAL_WARNINGS": "ON",
    "LLAMA_BUILD_APP": "OFF",
    "LLAMA_BUILD_EXAMPLES": "OFF",
    "LLAMA_BUILD_SERVER": "ON",
    "LLAMA_BUILD_TESTS": "ON",
    "LLAMA_BUILD_TOOLS": "ON",
    "LLAMA_BUILD_UI": "OFF",
    "LLAMA_USE_PREBUILT_UI": "OFF",
    "LLAMA_OPENSSL": "OFF",
    "GGML_BLAS": "OFF",
    "GGML_CCACHE": "OFF",
    "GGML_CPU": "ON",
    "GGML_CUDA": "OFF",
    "GGML_FATAL_WARNINGS": "ON",
    "GGML_HIP": "OFF",
    "GGML_LLAMAFILE": "OFF",
    "GGML_NATIVE": "OFF",
    "GGML_OPENCL": "OFF",
    "GGML_OPENMP": "OFF",
    "GGML_RPC": "OFF",
    "GGML_SYCL": "OFF",
    "GGML_VULKAN": "ON",
}

# llama-mtmd-cli exercises a projector outside the server, which is what lets a
# vision failure be attributed between the projector, the chat template, and
# the request shape. llama-quantize derives F16 from a publisher's BF16 on the
# appliance itself, since RADV on Raven2 advertises shaderFloat16 and no
# bfloat16 extension.
VULKAN_TARGETS: tuple[str, ...] = (
    "llama-server",
    "llama-cli",
    "llama-mtmd-cli",
    "llama-quantize",
)


class ToolchainMissing(RuntimeError):
    """The source build's own tools are absent; the prebuilt bundle path
    needs none of them."""


@dataclass(frozen=True, slots=True)
class BuildInvocation:
    """The two argv lists a source build runs, in the order it runs them."""

    configure: tuple[str, ...]
    build: tuple[str, ...]


def missing_commands(commands: tuple[str, ...] = REQUIRED_COMMANDS) -> tuple[str, ...]:
    """Every command `shutil.which` fails to resolve, in the declared order."""
    return tuple(name for name in commands if shutil.which(name) is None)


def require_toolchain(commands: tuple[str, ...] = REQUIRED_COMMANDS) -> None:
    """Refuse with every absent tool named at once."""
    absent = missing_commands(commands)
    if absent:
        raise ToolchainMissing(
            f"the source build needs {', '.join(absent)} on PATH; the prebuilt "
            "deployment bundle needs none of them"
        )


def configure_argv(
    source_tree: Path | str, build_dir: Path | str, defines: dict[str, str]
) -> tuple[str, ...]:
    """The `cmake -S ... -B ... -G Ninja -D...` argv, defines in dict order."""
    argv = ["cmake", "-S", str(source_tree), "-B", str(build_dir), "-G", GENERATOR]
    argv.extend(f"-D{key}={value}" for key, value in defines.items())
    return tuple(argv)


def build_argv(
    build_dir: Path | str, targets: tuple[str, ...] | list[str], jobs: int
) -> tuple[str, ...]:
    """The `cmake --build ... --parallel N --target ...` argv, targets in order."""
    return ("cmake", "--build", str(build_dir), "--parallel", str(jobs), "--target", *targets)


def configure_and_build(
    source_tree: Path | str,
    build_dir: Path | str,
    defines: dict[str, str],
    targets: tuple[str, ...] | list[str],
    *,
    jobs: int,
) -> BuildInvocation:
    """Configure and build, returning the two argv lists that ran.

    The toolchain gate runs first, so a machine without the tools refuses
    before CMake writes a cache directory it would have to be told to discard.
    """
    if jobs < 1:
        raise ValueError(f"parallel job count must be positive: {jobs}")
    require_toolchain()
    invocation = BuildInvocation(
        configure=configure_argv(source_tree, build_dir, defines),
        build=build_argv(build_dir, targets, jobs),
    )
    subprocess.run(list(invocation.configure), check=True)
    subprocess.run(list(invocation.build), check=True)
    return invocation
