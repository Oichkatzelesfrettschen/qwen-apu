"""Typed reader over config/native-builds.toml, the declarative native build recipes.

remote/build-llama-vulkan.sh and remote/build-stable-diffusion-vulkan.sh hold
the cmake invocation that compiles each engine. This module reads the TOML
restatement of those invocations and refuses the file whenever its two
statements of one fact disagree: every `[*.backends]` and `[*.build]` key maps
to one cmake define, the declared value must equal that define, and every
define must be named by exactly one such key. A recipe therefore carries a
single formulation of the build that a bundle manifest can record and an
install can check.

`load_native_builds` refuses an unknown key at every level, so a field added to
the TOML reaches a reader here before it reaches a build.
"""

from __future__ import annotations

import tomllib
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType

SCHEMA = 1

# Each backend and build key names the cmake define that states it. The two
# engines share GGML_* defines and differ on their own prefix, so the tables are
# per engine rather than merged.
_BACKEND_DEFINES: Mapping[str, Mapping[str, str]] = MappingProxyType(
    {
        "llama": MappingProxyType(
            {
                "vulkan": "GGML_VULKAN",
                "cpu": "GGML_CPU",
                "blas": "GGML_BLAS",
                "cuda": "GGML_CUDA",
                "hip": "GGML_HIP",
                "opencl": "GGML_OPENCL",
                "rpc": "GGML_RPC",
                "sycl": "GGML_SYCL",
            }
        ),
        "stable_diffusion": MappingProxyType(
            {
                "vulkan": "SD_VULKAN",
                "blas": "GGML_BLAS",
                "cuda": "SD_CUDA",
                "hipblas": "SD_HIPBLAS",
                "metal": "SD_METAL",
                "musa": "SD_MUSA",
                "opencl": "SD_OPENCL",
                "sycl": "SD_SYCL",
            }
        ),
    }
)

_BUILD_DEFINES: Mapping[str, Mapping[str, str]] = MappingProxyType(
    {
        "llama": MappingProxyType(
            {
                "shared_libs": "BUILD_SHARED_LIBS",
                "ccache": "GGML_CCACHE",
                "native": "GGML_NATIVE",
                "openmp": "GGML_OPENMP",
                "llamafile": "GGML_LLAMAFILE",
                "llama_fatal_warnings": "LLAMA_FATAL_WARNINGS",
                "ggml_fatal_warnings": "GGML_FATAL_WARNINGS",
                "build_app": "LLAMA_BUILD_APP",
                "build_examples": "LLAMA_BUILD_EXAMPLES",
                "build_server": "LLAMA_BUILD_SERVER",
                "build_tests": "LLAMA_BUILD_TESTS",
                "build_tools": "LLAMA_BUILD_TOOLS",
                "build_ui": "LLAMA_BUILD_UI",
                "prebuilt_ui": "LLAMA_USE_PREBUILT_UI",
                "openssl": "LLAMA_OPENSSL",
            }
        ),
        "stable_diffusion": MappingProxyType(
            {
                "shared_libs": "SD_BUILD_SHARED_LIBS",
                "ccache": "GGML_CCACHE",
                "native": "GGML_NATIVE",
                "openmp": "GGML_OPENMP",
                "build_examples": "SD_BUILD_EXAMPLES",
                "export_compile_commands": "CMAKE_EXPORT_COMPILE_COMMANDS",
            }
        ),
    }
)

_BUILD_TYPE_DEFINE = "CMAKE_BUILD_TYPE"

_RECIPE_REQUIRED_KEYS = (
    "profile",
    "build_script",
    "build_directory_name",
    "install_prefix",
    "generator",
    "upstream_repository",
    "upstream_commit",
    "targets",
    "required_commands",
    "backends",
    "build",
    "cmake_defines",
)
_RECIPE_OPTIONAL_KEYS = (
    "submodule_commit",
    "device",
    "patch_series",
    "patched_sources",
)
_SHADERC_KEYS = (
    "project",
    "revision",
    "archive_url",
    "archive_sha256",
    "prefix",
    "minimum_glslc_version",
)

_COMMIT_LENGTH = 40
_HEX_DIGITS = frozenset("0123456789abcdef")


class NativeRecipeError(ValueError):
    """A recipe field, value, or cross-check fails its own rule.

    The message names the section, the key, and the reason, so a reader acts on
    one line without opening the TOML beside the build script.
    """


def _require_hex(value: str, *, length: int, label: str) -> str:
    if len(value) != length or not set(value) <= _HEX_DIGITS:
        raise NativeRecipeError(f"{label} is not a {length}-digit lowercase hex digest: {value}")
    return value


def _require_str(table: Mapping[str, object], key: str, *, label: str) -> str:
    value = table.get(key)
    if not isinstance(value, str) or not value:
        raise NativeRecipeError(f"{label}: {key} is not a nonempty string")
    return value


def _require_str_tuple(table: Mapping[str, object], key: str, *, label: str) -> tuple[str, ...]:
    value = table.get(key)
    if not isinstance(value, list) or not value:
        raise NativeRecipeError(f"{label}: {key} is not a nonempty array of strings")
    for entry in value:
        if not isinstance(entry, str) or not entry:
            raise NativeRecipeError(f"{label}: {key} holds an entry that is not a nonempty string")
    names = tuple(str(entry) for entry in value)
    if len(set(names)) != len(names):
        raise NativeRecipeError(f"{label}: {key} repeats an entry")
    return names


def _require_relative_prefix(value: str, *, label: str) -> str:
    """An install prefix is `opt/<engine>`, two components under the runtime root.

    The depth is the rule rather than a convention:
    `qwen_apu.install.native.installed_bundles` enumerates the store by reading
    `<opt>/<engine>/<digest>/`, so a deeper prefix would install through
    `_store_root` and then stay invisible to every reader of the store. An
    absolute prefix or a `..` segment escapes the root
    `qwen_apu.runtime.paths` declares, which is the boundary the whole no-sudo
    install path rests on.
    """
    parts = Path(value).parts
    if value.startswith("/") or ".." in parts:
        raise NativeRecipeError(f"{label}: install_prefix is not a relative path: {value}")
    if len(parts) != 2 or parts[0] != "opt":
        raise NativeRecipeError(
            f"{label}: install_prefix is not opt/<engine>, two components: {value}"
        )
    return value


@dataclass(frozen=True, slots=True)
class ShadercToolchain:
    """The pinned SPIR-V producer, restated from remote/shaderc-toolchain.tsv."""

    project: str
    revision: str
    archive_url: str
    archive_sha256: str
    prefix: str
    minimum_glslc_version: str


@dataclass(frozen=True, slots=True)
class NativeRecipe:
    """One engine's build recipe: the pin, the generator, the targets, the defines."""

    name: str
    profile: str
    build_script: str
    build_directory_name: str
    install_prefix: str
    generator: str
    upstream_repository: str
    upstream_commit: str
    submodule_commit: str | None
    device: str | None
    patch_series: str | None
    patched_sources: str | None
    targets: tuple[str, ...]
    required_commands: tuple[str, ...]
    backends: Mapping[str, bool]
    build: Mapping[str, bool | str]
    cmake_defines: Mapping[str, str]

    def cmake_argv(self, source: Path, build: Path) -> tuple[str, ...]:
        """The configure argv this recipe states, in the order the TOML lists the defines."""
        argv = ["cmake", "-S", str(source), "-B", str(build), "-G", self.generator]
        argv.extend(f"-D{key}={value}" for key, value in self.cmake_defines.items())
        return tuple(argv)

    def build_argv(self, build: Path, *, jobs: int) -> tuple[str, ...]:
        """The compile argv this recipe states, one `--target` list over every target."""
        return (
            "cmake",
            "--build",
            str(build),
            "--parallel",
            str(jobs),
            "--target",
            *self.targets,
        )


@dataclass(frozen=True, slots=True)
class NativeBuilds:
    """Every recipe config/native-builds.toml declares, keyed by section name."""

    schema: int
    recipes: Mapping[str, NativeRecipe]
    shaderc: ShadercToolchain

    def recipe(self, name: str) -> NativeRecipe:
        found = self.recipes.get(name)
        if found is None:
            known = ", ".join(sorted(self.recipes))
            raise NativeRecipeError(f"no recipe named {name}; the file declares {known}")
        return found


def default_recipe_path() -> Path:
    """config/native-builds.toml under the checkout this module sits in."""
    return Path(__file__).resolve().parents[3] / "config" / "native-builds.toml"


def _parse_boolean_view(
    table: Mapping[str, object],
    defines: Mapping[str, str],
    cmake_defines: Mapping[str, str],
    *,
    label: str,
) -> dict[str, bool]:
    """Read one boolean view and require each value to equal its cmake define.

    A `true` states `ON` and a `false` states `OFF`; any other define value
    refuses, because a view that cannot state the define is a view that hides
    it.
    """
    parsed: dict[str, bool] = {}
    for key, value in table.items():
        define = defines.get(key)
        if define is None:
            known = ", ".join(sorted(defines))
            raise NativeRecipeError(f"{label}: unknown key {key}; this view names {known}")
        if not isinstance(value, bool):
            raise NativeRecipeError(f"{label}: {key} is not a boolean")
        declared = cmake_defines.get(define)
        if declared is None:
            raise NativeRecipeError(f"{label}: {key} names {define}, which cmake_defines omits")
        expected = "ON" if value else "OFF"
        if declared != expected:
            raise NativeRecipeError(
                f"{label}: {key} is {str(value).lower()} while {define} is {declared}"
            )
        parsed[key] = value
    return parsed


def _parse_recipe(name: str, table: Mapping[str, object]) -> NativeRecipe:
    label = f"[{name}]"
    backend_defines = _BACKEND_DEFINES.get(name)
    build_defines = _BUILD_DEFINES.get(name)
    if backend_defines is None or build_defines is None:
        known = ", ".join(sorted(_BACKEND_DEFINES))
        raise NativeRecipeError(
            f"{label}: no define mapping exists for this engine; known: {known}"
        )

    allowed = set(_RECIPE_REQUIRED_KEYS) | set(_RECIPE_OPTIONAL_KEYS)
    unknown = sorted(set(table) - allowed)
    if unknown:
        raise NativeRecipeError(f"{label}: unknown keys {', '.join(unknown)}")
    missing = sorted(key for key in _RECIPE_REQUIRED_KEYS if key not in table)
    if missing:
        raise NativeRecipeError(f"{label}: missing keys {', '.join(missing)}")

    raw_defines = table["cmake_defines"]
    if not isinstance(raw_defines, dict) or not raw_defines:
        raise NativeRecipeError(f"{label}: cmake_defines is not a nonempty table")
    cmake_defines: dict[str, str] = {}
    for key, value in raw_defines.items():
        if not isinstance(value, str) or not value:
            raise NativeRecipeError(f"{label}: cmake_defines.{key} is not a nonempty string")
        cmake_defines[key] = value

    raw_backends = table["backends"]
    raw_build = table["build"]
    if not isinstance(raw_backends, dict) or not isinstance(raw_build, dict):
        raise NativeRecipeError(f"{label}: backends and build are tables")

    backends = _parse_boolean_view(
        raw_backends, backend_defines, cmake_defines, label=f"{label}.backends"
    )
    build_type = _require_str(raw_build, "build_type", label=f"{label}.build")
    if cmake_defines.get(_BUILD_TYPE_DEFINE) != build_type:
        raise NativeRecipeError(
            f"{label}.build: build_type is {build_type} while "
            f"{_BUILD_TYPE_DEFINE} is {cmake_defines.get(_BUILD_TYPE_DEFINE)}"
        )
    build_view: dict[str, bool | str] = {"build_type": build_type}
    build_view.update(
        _parse_boolean_view(
            {key: value for key, value in raw_build.items() if key != "build_type"},
            build_defines,
            cmake_defines,
            label=f"{label}.build",
        )
    )

    # Every define is named by exactly one view key, so a flag the views cannot
    # express is a flag a reader of this file would miss.
    named = {_BUILD_TYPE_DEFINE}
    named.update(backend_defines[key] for key in backends)
    named.update(build_defines[key] for key in build_view if key != "build_type")
    unnamed = sorted(set(cmake_defines) - named)
    if unnamed:
        raise NativeRecipeError(f"{label}: no backends or build key names {', '.join(unnamed)}")

    submodule = table.get("submodule_commit")
    if submodule is not None and not isinstance(submodule, str):
        raise NativeRecipeError(f"{label}: submodule_commit is not a string")
    device = table.get("device")
    if device is not None and not isinstance(device, str):
        raise NativeRecipeError(f"{label}: device is not a string")
    patch_series = table.get("patch_series")
    if patch_series is not None and not isinstance(patch_series, str):
        raise NativeRecipeError(f"{label}: patch_series is not a string")
    patched_sources = table.get("patched_sources")
    if patched_sources is not None and not isinstance(patched_sources, str):
        raise NativeRecipeError(f"{label}: patched_sources is not a string")

    return NativeRecipe(
        name=name,
        profile=_require_str(table, "profile", label=label),
        build_script=_require_str(table, "build_script", label=label),
        build_directory_name=_require_str(table, "build_directory_name", label=label),
        install_prefix=_require_relative_prefix(
            _require_str(table, "install_prefix", label=label), label=label
        ),
        generator=_require_str(table, "generator", label=label),
        upstream_repository=_require_str(table, "upstream_repository", label=label),
        upstream_commit=_require_hex(
            _require_str(table, "upstream_commit", label=label),
            length=_COMMIT_LENGTH,
            label=f"{label}: upstream_commit",
        ),
        submodule_commit=(
            _require_hex(submodule, length=_COMMIT_LENGTH, label=f"{label}: submodule_commit")
            if submodule is not None
            else None
        ),
        device=device,
        patch_series=patch_series,
        patched_sources=patched_sources,
        targets=_require_str_tuple(table, "targets", label=label),
        required_commands=_require_str_tuple(table, "required_commands", label=label),
        backends=MappingProxyType(backends),
        build=MappingProxyType(build_view),
        cmake_defines=MappingProxyType(cmake_defines),
    )


def _parse_shaderc(table: Mapping[str, object]) -> ShadercToolchain:
    label = "[shaderc]"
    unknown = sorted(set(table) - set(_SHADERC_KEYS))
    if unknown:
        raise NativeRecipeError(f"{label}: unknown keys {', '.join(unknown)}")
    missing = sorted(key for key in _SHADERC_KEYS if key not in table)
    if missing:
        raise NativeRecipeError(f"{label}: missing keys {', '.join(missing)}")
    return ShadercToolchain(
        project=_require_str(table, "project", label=label),
        revision=_require_str(table, "revision", label=label),
        archive_url=_require_str(table, "archive_url", label=label),
        archive_sha256=_require_hex(
            _require_str(table, "archive_sha256", label=label),
            length=64,
            label=f"{label}: archive_sha256",
        ),
        prefix=_require_str(table, "prefix", label=label),
        minimum_glslc_version=_require_str(table, "minimum_glslc_version", label=label),
    )


def load_native_builds(path: Path | str | None = None) -> NativeBuilds:
    """Parse config/native-builds.toml whole, refusing before any recipe answers.

    The whole file validates first, the discipline every ledger reader in
    `qwen_apu.config` applies: a caller reading one recipe never trusts a file
    a sibling section has made unsafe to read.
    """
    resolved = Path(path) if path is not None else default_recipe_path()
    if not resolved.is_file():
        raise NativeRecipeError(f"native build recipes are unreadable: {resolved}")
    with resolved.open("rb") as handle:
        document = tomllib.load(handle)

    schema = document.get("schema")
    if schema != SCHEMA:
        raise NativeRecipeError(f"{resolved}: schema is {schema!r}, expected {SCHEMA}")
    shaderc_table = document.get("shaderc")
    if not isinstance(shaderc_table, dict):
        raise NativeRecipeError(f"{resolved}: [shaderc] is absent")

    recipes: dict[str, NativeRecipe] = {}
    for key, value in document.items():
        if key in {"schema", "shaderc"}:
            continue
        if not isinstance(value, dict):
            raise NativeRecipeError(f"{resolved}: top-level key {key} is not a recipe table")
        recipes[key] = _parse_recipe(key, value)
    if not recipes:
        raise NativeRecipeError(f"{resolved}: the file declares no recipe")

    return NativeBuilds(
        schema=SCHEMA,
        recipes=MappingProxyType(recipes),
        shaderc=_parse_shaderc(shaderc_table),
    )
