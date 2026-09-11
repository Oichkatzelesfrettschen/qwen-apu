"""Parity between config/native-builds.toml and the build scripts, and the bundle path end to end.

The recipe tests parse each shell script's own text -- its `-D` flags, its
`--target` list, its pinned commits, its required commands -- and compare both
directions against the TOML, so a flag added to either side without the other
fails here rather than at a build.

The ELF tests run against two fixtures. `_build_elf64` assembles a minimal
ELF64 image byte by byte, which gives the parser a `PT_LOAD` whose `p_vaddr`
differs from its `p_offset` (a `DT_STRTAB` read as a file offset resolves
wrongly there and correctly where the two coincide) and a `.gnu.version_r`
table of two entries so the entry-relative `vn_next` walk is exercised. A
second fixture compiles a real executable with `cc` where one is installed, so
the parser also meets a linker's own output.
"""

from __future__ import annotations

import dataclasses
import hashlib
import io
import json
import os
import re
import shutil
import struct
import subprocess
import tarfile
from collections.abc import Sequence
from pathlib import Path

import pytest

from qwen_apu.config.native import (
    NativeRecipe,
    NativeRecipeError,
    load_native_builds,
)
from qwen_apu.install.artifacts import (
    ArtifactStoreError,
    atomic_install,
    digest_file,
    directory_digest,
    store_path,
)
from qwen_apu.install.native import (
    MANIFEST_NAME,
    Closure,
    ElfFormatError,
    NativeBundleError,
    _store_root,
    closure_satisfied,
    default_search_dirs,
    host_glibc_version,
    install_bundle,
    installed_bundles,
    manifest_from_json,
    manifest_to_json,
    require_host_glibc,
    shared_library_closure,
    stage_bundle,
    verify_bundle,
)
from qwen_apu.runtime.paths import RuntimePaths

TREE = Path(__file__).resolve().parents[1]

_DEFINE = re.compile(r"-D([A-Za-z0-9_]+)=([^\s\\]+)")


# ---------------------------------------------------------------------------
# Shell script readers
# ---------------------------------------------------------------------------


def _joined_command(text: str, opening: str) -> str:
    """One backslash-continued shell command, from the line that opens it."""
    lines = text.splitlines()
    for start, line in enumerate(lines):
        if not line.lstrip().startswith(opening):
            continue
        collected = [line]
        cursor = start
        while collected[-1].rstrip().endswith("\\"):
            cursor += 1
            collected.append(lines[cursor])
        return " ".join(part.rstrip().rstrip("\\") for part in collected)
    raise AssertionError(f"no command opening with {opening!r}")


def _script_defines(path: Path) -> dict[str, str]:
    command = _joined_command(path.read_text(encoding="utf-8"), "cmake -S")
    found: dict[str, str] = {}
    for key, value in _DEFINE.findall(command):
        assert key not in found, f"{path.name} passes -D{key} twice"
        found[key] = value
    return found


def _script_targets(path: Path) -> tuple[str, ...]:
    command = _joined_command(path.read_text(encoding="utf-8"), "cmake --build")
    _, _, tail = command.partition("--target")
    assert tail, f"{path.name} names no --target"
    return tuple(tail.split())


def _script_assignment(path: Path, name: str) -> str:
    match = re.search(rf"^{name}=(\S+)$", path.read_text(encoding="utf-8"), re.MULTILINE)
    assert match is not None, f"{path.name} assigns no {name}"
    return match.group(1)


def _script_required_commands(path: Path) -> tuple[str, ...]:
    match = re.search(
        r"^for required_command in (.+); do$", path.read_text(encoding="utf-8"), re.MULTILINE
    )
    assert match is not None, f"{path.name} enumerates no required commands"
    return tuple(match.group(1).split())


# ---------------------------------------------------------------------------
# Recipe parity
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def builds():
    return load_native_builds()


@pytest.mark.parametrize("engine", ["llama", "stable_diffusion"])
def test_cmake_defines_match_the_build_script(builds, engine):
    recipe = builds.recipe(engine)
    script = TREE / recipe.build_script
    declared = dict(recipe.cmake_defines)
    passed = _script_defines(script)
    assert declared == passed
    # Order carries the reviewability of the diff between the two files, so the
    # TOML lists the defines in the order the script passes them.
    assert list(declared) == list(passed)


@pytest.mark.parametrize("engine", ["llama", "stable_diffusion"])
def test_targets_match_the_build_script(builds, engine):
    recipe = builds.recipe(engine)
    assert recipe.targets == _script_targets(TREE / recipe.build_script)


def test_llama_targets_match_the_scripts_own_output_check(builds):
    """remote/build-llama-vulkan.sh re-states its targets in a `required_output` loop."""
    script = (TREE / builds.recipe("llama").build_script).read_text(encoding="utf-8")
    match = re.search(r"^for required_output in (.+); do$", script, re.MULTILINE)
    assert match is not None
    assert tuple(match.group(1).split()) == builds.recipe("llama").targets


@pytest.mark.parametrize("engine", ["llama", "stable_diffusion"])
def test_pinned_commit_matches_the_build_script(builds, engine):
    recipe = builds.recipe(engine)
    script = TREE / recipe.build_script
    assert recipe.upstream_commit == _script_assignment(script, "expected_commit")
    if recipe.submodule_commit is not None:
        assert recipe.submodule_commit == _script_assignment(script, "expected_ggml_commit")


@pytest.mark.parametrize("engine", ["llama", "stable_diffusion"])
def test_required_commands_match_the_build_script(builds, engine):
    recipe = builds.recipe(engine)
    assert recipe.required_commands == _script_required_commands(TREE / recipe.build_script)


@pytest.mark.parametrize("engine", ["llama", "stable_diffusion"])
def test_build_directory_name_matches_the_build_script(builds, engine):
    recipe = builds.recipe(engine)
    text = (TREE / recipe.build_script).read_text(encoding="utf-8")
    match = re.search(
        r"^build_directory=\$\{2:-\$source_directory/([\w.-]+)\}$", text, re.MULTILINE
    )
    assert match is not None
    assert recipe.build_directory_name == match.group(1)


def test_stable_diffusion_cmake_flags_string_restates_the_same_defines(builds):
    """The script records its own flags for the build manifest; both statements agree."""
    recipe = builds.recipe("stable_diffusion")
    text = (TREE / recipe.build_script).read_text(encoding="utf-8")
    match = re.search(r"^cmake_flags='([^']+)'$", text, re.MULTILINE)
    assert match is not None
    recorded = dict(entry.split("=", 1) for entry in match.group(1).split())
    assert recorded == dict(recipe.cmake_defines)
    assert list(recorded) == list(recipe.cmake_defines)


def test_stable_diffusion_device_is_the_one_the_script_requires(builds):
    recipe = builds.recipe("stable_diffusion")
    text = (TREE / recipe.build_script).read_text(encoding="utf-8")
    assert recipe.device is not None
    assert recipe.device in text


def test_shaderc_pin_matches_the_ledger(builds):
    ledger = (TREE / "remote" / "shaderc-toolchain.tsv").read_text(encoding="utf-8")
    rows = dict(
        line.split("\t", 1)
        for line in ledger.splitlines()
        if line and not line.startswith("#") and "\t" in line
    )
    shaderc = builds.shaderc
    assert rows["project"] == shaderc.project
    assert rows["revision"] == shaderc.revision
    assert rows["archive_url"] == shaderc.archive_url
    assert rows["archive_sha256"] == shaderc.archive_sha256
    assert rows["prefix"] == shaderc.prefix
    assert rows["minimum_glslc_version"] == shaderc.minimum_glslc_version


def test_patch_series_reference_names_a_tracked_ledger(builds):
    recipe = builds.recipe("llama")
    assert recipe.patch_series is not None
    assert (TREE / recipe.patch_series).is_file()
    assert recipe.patched_sources is not None
    assert (TREE / recipe.patched_sources).is_file()


def test_install_prefixes_are_distinct_and_two_components_under_opt(builds):
    """`installed_bundles` reads `<opt>/<engine>/<digest>/`, so the depth is the
    rule that keeps every installed bundle enumerable."""
    prefixes = [recipe.install_prefix for recipe in builds.recipes.values()]
    assert len(set(prefixes)) == len(prefixes)
    assert all(Path(prefix).parts[0] == "opt" for prefix in prefixes)
    assert all(len(Path(prefix).parts) == 2 for prefix in prefixes)


def test_cmake_argv_carries_every_define_in_order(builds):
    recipe = builds.recipe("llama")
    argv = recipe.cmake_argv(Path("/src"), Path("/build"))
    assert argv[:7] == ("cmake", "-S", "/src", "-B", "/build", "-G", "Ninja")
    assert list(argv[7:]) == [f"-D{key}={value}" for key, value in recipe.cmake_defines.items()]


def test_build_argv_names_every_target(builds):
    recipe = builds.recipe("llama")
    argv = recipe.build_argv(Path("/build"), jobs=2)
    assert argv[-len(recipe.targets) :] == recipe.targets
    assert "--parallel" in argv


# ---------------------------------------------------------------------------
# Recipe refusals
# ---------------------------------------------------------------------------


def _write_recipe(path: Path, *, mutate) -> Path:
    text = (TREE / "config" / "native-builds.toml").read_text(encoding="utf-8")
    path.write_text(mutate(text), encoding="utf-8")
    return path


def test_loader_refuses_an_unknown_recipe_key(tmp_path):
    target = _write_recipe(
        tmp_path / "native-builds.toml",
        mutate=lambda text: text.replace("[llama]\n", '[llama]\nunexpected = "x"\n', 1),
    )
    with pytest.raises(NativeRecipeError, match="unknown keys unexpected"):
        load_native_builds(target)


def test_loader_refuses_a_view_that_disagrees_with_its_define(tmp_path):
    target = _write_recipe(
        tmp_path / "native-builds.toml",
        mutate=lambda text: text.replace(
            "vulkan = true\ncpu = true", "vulkan = false\ncpu = true", 1
        ),
    )
    with pytest.raises(NativeRecipeError, match="vulkan is false while GGML_VULKAN is ON"):
        load_native_builds(target)


def test_loader_refuses_a_define_no_view_names(tmp_path):
    target = _write_recipe(
        tmp_path / "native-builds.toml",
        mutate=lambda text: text.replace(
            'GGML_VULKAN = "ON"\n', 'GGML_VULKAN = "ON"\nGGML_METAL = "OFF"\n', 1
        ),
    )
    with pytest.raises(NativeRecipeError, match="no backends or build key names GGML_METAL"):
        load_native_builds(target)


def test_loader_refuses_a_build_type_that_disagrees(tmp_path):
    target = _write_recipe(
        tmp_path / "native-builds.toml",
        mutate=lambda text: text.replace('build_type = "Release"', 'build_type = "Debug"', 1),
    )
    with pytest.raises(NativeRecipeError, match="build_type is Debug"):
        load_native_builds(target)


def test_loader_refuses_a_wrong_schema(tmp_path):
    target = _write_recipe(
        tmp_path / "native-builds.toml",
        mutate=lambda text: text.replace("schema = 1", "schema = 2", 1),
    )
    with pytest.raises(NativeRecipeError, match="schema is 2"):
        load_native_builds(target)


def test_loader_refuses_an_absolute_install_prefix(tmp_path):
    target = _write_recipe(
        tmp_path / "native-builds.toml",
        mutate=lambda text: text.replace(
            'install_prefix = "opt/llama"', 'install_prefix = "/opt/llama"', 1
        ),
    )
    with pytest.raises(NativeRecipeError, match="install_prefix is not a relative path"):
        load_native_builds(target)


def test_loader_refuses_an_install_prefix_deeper_than_opt_engine(tmp_path):
    target = _write_recipe(
        tmp_path / "native-builds.toml",
        mutate=lambda text: text.replace(
            'install_prefix = "opt/llama"', 'install_prefix = "opt/native/llama"', 1
        ),
    )
    with pytest.raises(NativeRecipeError, match="not opt/<engine>"):
        load_native_builds(target)


# ---------------------------------------------------------------------------
# The hand-built ELF64 fixture
# ---------------------------------------------------------------------------

_PT_LOAD = 1
_PT_DYNAMIC = 2
_PT_INTERP = 3
_DT_NULL = 0
_DT_NEEDED = 1
_DT_STRTAB = 5
_DT_STRSZ = 10
_DT_SONAME = 14
_SHT_STRTAB = 3
_SHT_GNU_VERNEED = 0x6FFFFFFE

_INTERP_OFFSET = 0x100
_DYNSTR_OFFSET = 0x200
_DYNAMIC_OFFSET = 0x400
_VERNEED_OFFSET = 0x600
_SHSTRTAB_OFFSET = 0x800
_SECTION_HEADER_OFFSET = 0x900
_LOAD_FILESZ = 0x800
# The load segment maps at an address unequal to its file offset, which is what
# separates a correct DT_STRTAB resolution from one that reads the address as a
# file offset and happens to work on a layout where the two coincide.
_LOAD_VADDR = 0x400000


class _StringTable:
    def __init__(self) -> None:
        self._payload = bytearray(b"\0")
        self._index: dict[str, int] = {"": 0}

    def add(self, text: str) -> int:
        if text not in self._index:
            self._index[text] = len(self._payload)
            self._payload.extend(text.encode("utf-8") + b"\0")
        return self._index[text]

    @property
    def payload(self) -> bytes:
        return bytes(self._payload)


def _build_elf64(
    *,
    needed: Sequence[str] = (),
    interp: str | None = "/lib64/ld-linux-x86-64.so.2",
    verneed: Sequence[tuple[str, Sequence[str]]] = (),
    soname: str | None = None,
    with_dynamic: bool = True,
) -> bytes:
    """Assemble a minimal ELF64 image stating exactly the fixture's dependencies."""
    dynstr = _StringTable()
    needed_indices = [dynstr.add(name) for name in needed]
    soname_index = dynstr.add(soname) if soname is not None else None
    verneed_entries = [
        (dynstr.add(file_name), [dynstr.add(version) for version in versions])
        for file_name, versions in verneed
    ]

    dynamic = bytearray()
    for index in needed_indices:
        dynamic.extend(struct.pack("<qQ", _DT_NEEDED, index))
    if soname_index is not None:
        dynamic.extend(struct.pack("<qQ", _DT_SONAME, soname_index))
    dynamic.extend(struct.pack("<qQ", _DT_STRTAB, _LOAD_VADDR + _DYNSTR_OFFSET))
    dynamic.extend(struct.pack("<qQ", _DT_STRSZ, len(dynstr.payload)))
    dynamic.extend(struct.pack("<qQ", _DT_NULL, 0))

    verneed_payload = bytearray()
    for position, (file_index, version_indices) in enumerate(verneed_entries):
        last_entry = position == len(verneed_entries) - 1
        entry_size = 16 + 16 * len(version_indices)
        verneed_payload.extend(
            struct.pack(
                "<HHIII",
                1,
                len(version_indices),
                file_index,
                16,
                0 if last_entry else entry_size,
            )
        )
        for aux_position, name_index in enumerate(version_indices):
            last_aux = aux_position == len(version_indices) - 1
            verneed_payload.extend(
                struct.pack("<IHHII", 0, 0, 0, name_index, 0 if last_aux else 16)
            )

    shstrtab = _StringTable()
    dynstr_name = shstrtab.add(".dynstr")
    verneed_name = shstrtab.add(".gnu.version_r")
    shstrtab_name = shstrtab.add(".shstrtab")

    segments: list[bytes] = [
        struct.pack(
            "<IIQQQQQQ",
            _PT_LOAD,
            5,
            0,
            _LOAD_VADDR,
            _LOAD_VADDR,
            _LOAD_FILESZ,
            _LOAD_FILESZ,
            0x1000,
        )
    ]
    if interp is not None:
        segments.append(
            struct.pack(
                "<IIQQQQQQ",
                _PT_INTERP,
                4,
                _INTERP_OFFSET,
                _LOAD_VADDR + _INTERP_OFFSET,
                _LOAD_VADDR + _INTERP_OFFSET,
                len(interp) + 1,
                len(interp) + 1,
                1,
            )
        )
    if with_dynamic:
        segments.append(
            struct.pack(
                "<IIQQQQQQ",
                _PT_DYNAMIC,
                6,
                _DYNAMIC_OFFSET,
                _LOAD_VADDR + _DYNAMIC_OFFSET,
                _LOAD_VADDR + _DYNAMIC_OFFSET,
                len(dynamic),
                len(dynamic),
                8,
            )
        )

    sections = [
        struct.pack("<IIQQQQIIQQ", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        struct.pack(
            "<IIQQQQIIQQ",
            dynstr_name,
            _SHT_STRTAB,
            2,
            _LOAD_VADDR + _DYNSTR_OFFSET,
            _DYNSTR_OFFSET,
            len(dynstr.payload),
            0,
            0,
            1,
            0,
        ),
        struct.pack(
            "<IIQQQQIIQQ",
            verneed_name,
            _SHT_GNU_VERNEED,
            2,
            _LOAD_VADDR + _VERNEED_OFFSET,
            _VERNEED_OFFSET,
            len(verneed_payload),
            1,
            len(verneed_entries),
            8,
            0,
        ),
        struct.pack(
            "<IIQQQQIIQQ",
            shstrtab_name,
            _SHT_STRTAB,
            0,
            0,
            _SHSTRTAB_OFFSET,
            len(shstrtab.payload),
            0,
            0,
            1,
            0,
        ),
    ]

    image = bytearray(_SECTION_HEADER_OFFSET + 64 * len(sections))
    header = b"\x7fELF" + bytes([2, 1, 1]) + bytes(9)
    header += struct.pack(
        "<HHIQQQIHHHHHH",
        2,
        0x3E,
        1,
        _LOAD_VADDR,
        64,
        _SECTION_HEADER_OFFSET,
        0,
        64,
        56,
        len(segments),
        64,
        len(sections),
        3,
    )
    image[0:64] = header
    image[64 : 64 + 56 * len(segments)] = b"".join(segments)
    if interp is not None:
        image[_INTERP_OFFSET : _INTERP_OFFSET + len(interp) + 1] = interp.encode() + b"\0"
    image[_DYNSTR_OFFSET : _DYNSTR_OFFSET + len(dynstr.payload)] = dynstr.payload
    image[_DYNAMIC_OFFSET : _DYNAMIC_OFFSET + len(dynamic)] = bytes(dynamic)
    image[_VERNEED_OFFSET : _VERNEED_OFFSET + len(verneed_payload)] = bytes(verneed_payload)
    image[_SHSTRTAB_OFFSET : _SHSTRTAB_OFFSET + len(shstrtab.payload)] = shstrtab.payload
    image[_SECTION_HEADER_OFFSET : _SECTION_HEADER_OFFSET + 64 * len(sections)] = b"".join(sections)
    return bytes(image)


def _write_elf(path: Path, **kwargs) -> Path:
    path.write_bytes(_build_elf64(**kwargs))
    path.chmod(0o755)
    return path


# ---------------------------------------------------------------------------
# ELF parsing
# ---------------------------------------------------------------------------


def test_hand_built_elf_yields_its_interpreter_and_sonames(tmp_path):
    elf = _write_elf(
        tmp_path / "probe",
        needed=["libstdc++.so.6", "libm.so.6", "libc.so.6"],
        soname="libprobe.so.1",
    )
    closure = shared_library_closure(elf)
    assert closure.interp == "/lib64/ld-linux-x86-64.so.2"
    assert closure.needed == ("libstdc++.so.6", "libm.so.6", "libc.so.6")
    assert closure.soname == "libprobe.so.1"


def test_glibc_required_takes_the_numeric_maximum_across_verneed_entries(tmp_path):
    """Two entries exercise the entry-relative `vn_next` walk, and `GLIBC_2.34`
    outranks `GLIBC_2.9` numerically where the strings sort the other way."""
    elf = _write_elf(
        tmp_path / "probe",
        needed=["libc.so.6", "libm.so.6"],
        verneed=[
            ("libc.so.6", ["GLIBC_2.9", "GLIBC_ABI_DT_RELR"]),
            ("libm.so.6", ["GLIBC_2.14", "GLIBC_2.34"]),
        ],
    )
    assert shared_library_closure(elf).glibc_required == "GLIBC_2.34"


def test_verneed_names_outside_the_glibc_vocabulary_are_skipped(tmp_path):
    elf = _write_elf(
        tmp_path / "probe",
        needed=["libstdc++.so.6"],
        verneed=[("libstdc++.so.6", ["GLIBCXX_3.4.32", "CXXABI_1.3.13", "GCC_3.0"])],
    )
    assert shared_library_closure(elf).glibc_required is None


def test_a_static_image_reads_as_an_empty_closure(tmp_path):
    elf = _write_elf(tmp_path / "static", needed=[], interp=None, with_dynamic=False)
    closure = shared_library_closure(elf)
    assert closure.needed == ()
    assert closure.interp is None
    assert closure.glibc_required is None


def test_a_non_elf_file_refuses(tmp_path):
    plain = tmp_path / "plain"
    plain.write_bytes(b"#!/bin/sh\nexit 0\n" + bytes(4096))
    with pytest.raises(ElfFormatError, match="no ELF magic"):
        shared_library_closure(plain)


def test_a_32_bit_image_refuses(tmp_path):
    image = bytearray(_build_elf64(needed=["libc.so.6"]))
    image[4] = 1
    path = tmp_path / "elf32"
    path.write_bytes(bytes(image))
    with pytest.raises(ElfFormatError, match="is not ELF64"):
        shared_library_closure(path)


def test_closure_resolves_against_a_directory_list(tmp_path):
    library_dir = tmp_path / "lib"
    library_dir.mkdir()
    (library_dir / "libc.so.6").write_bytes(b"")
    interpreter = tmp_path / "ld.so"
    interpreter.write_bytes(b"")
    closure = Closure(
        interp=str(interpreter),
        soname=None,
        needed=("libc.so.6", "libabsent.so.1"),
        glibc_required=None,
    )
    resolution = closure_satisfied(closure, [library_dir])
    assert resolution.missing == ("libabsent.so.1",)
    assert resolution.resolved["libc.so.6"] == library_dir / "libc.so.6"
    assert resolution.resolved[str(interpreter)] == interpreter
    assert not resolution.satisfied


def test_a_fully_resolved_closure_is_satisfied(tmp_path):
    library_dir = tmp_path / "lib"
    library_dir.mkdir()
    (library_dir / "libc.so.6").write_bytes(b"")
    closure = Closure(interp=None, soname=None, needed=("libc.so.6",), glibc_required=None)
    assert closure_satisfied(closure, [library_dir]).satisfied


def test_default_search_dirs_name_existing_directories():
    directories = default_search_dirs()
    assert directories
    assert all(directory.is_dir() for directory in directories)


@pytest.mark.skipif(shutil.which("cc") is None, reason="no cc on this host")
def test_a_linked_executable_resolves_against_the_hosts_own_loader_path(tmp_path):
    """A real linker's output, so the parser meets a PIE layout and a populated
    `.gnu.version_r` rather than the fixture's own assembly alone."""
    source = tmp_path / "probe.c"
    source.write_text("int main(void) { return 0; }\n", encoding="utf-8")
    binary = tmp_path / "probe"
    subprocess.run([shutil.which("cc"), str(source), "-o", str(binary)], check=True)
    closure = shared_library_closure(binary)
    assert any(name.startswith("libc.so") for name in closure.needed)
    assert closure.interp is not None and closure.interp.startswith("/")
    assert closure.glibc_required is None or closure.glibc_required.startswith("GLIBC_2.")
    assert closure_satisfied(closure).satisfied


def test_host_glibc_version_reads_as_a_glibc_string():
    reported = host_glibc_version()
    assert reported is None or re.fullmatch(r"GLIBC_[0-9]+\.[0-9]+", reported)


# ---------------------------------------------------------------------------
# Artifact store
# ---------------------------------------------------------------------------


def test_directory_digest_tracks_the_executable_bit(tmp_path):
    first = tmp_path / "a"
    second = tmp_path / "b"
    for root in (first, second):
        root.mkdir()
        (root / "tool").write_bytes(b"payload")
    (first / "tool").chmod(0o755)
    (second / "tool").chmod(0o644)
    assert directory_digest(first) != directory_digest(second)


def test_atomic_install_creates_then_reconciles(tmp_path):
    def stage(name: str, payload: bytes) -> Path:
        path = tmp_path / name
        path.mkdir()
        (path / "tool").write_bytes(payload)
        (path / "tool").chmod(0o755)
        return path

    final = tmp_path / "store" / ("a" * 64)
    first = atomic_install(stage("one", b"payload"), final)
    assert first.created and first.path == final
    second = atomic_install(stage("two", b"payload"), final)
    assert not second.created
    assert not (tmp_path / "two").exists()


def test_atomic_install_refuses_a_digest_directory_holding_other_content(tmp_path):
    final = tmp_path / "store" / ("b" * 64)
    final.mkdir(parents=True)
    (final / "tool").write_bytes(b"other")
    staging = tmp_path / "staging"
    staging.mkdir()
    (staging / "tool").write_bytes(b"payload")
    with pytest.raises(ArtifactStoreError, match="already holds a different tree"):
        atomic_install(staging, final)


def test_store_path_refuses_a_value_that_is_not_a_digest(tmp_path):
    with pytest.raises(ArtifactStoreError, match="not a sha256 hex digest"):
        store_path(tmp_path, "../escape")


def test_digest_file_streams_a_payload_larger_than_one_chunk(tmp_path):
    payload = os.urandom(3 * 1024 * 1024)
    path = tmp_path / "large"
    path.write_bytes(payload)
    assert digest_file(path) == hashlib.sha256(payload).hexdigest()


# ---------------------------------------------------------------------------
# Bundles
# ---------------------------------------------------------------------------


@pytest.fixture
def recipe(builds) -> NativeRecipe:
    """The llama recipe with the fixture's own two executables as its targets."""
    return dataclasses.replace(builds.recipe("llama"), targets=("probe-server", "probe-cli"))


@pytest.fixture
def build_tree(tmp_path) -> dict[str, Path]:
    root = tmp_path / "build" / "bin"
    root.mkdir(parents=True)
    return {
        "probe-server": _write_elf(
            root / "probe-server",
            needed=["libstdc++.so.6", "libc.so.6"],
            verneed=[("libc.so.6", ["GLIBC_2.14", "GLIBC_2.34"])],
        ),
        "probe-cli": _write_elf(
            root / "probe-cli",
            needed=["libc.so.6"],
            verneed=[("libc.so.6", ["GLIBC_2.14"])],
        ),
    }


PATCH_DIGESTS = {
    "llama-vulkan-low-priority.patch": "a" * 64,
    "llama-no-cpu-fallback.patch": "b" * 64,
}
COMPILER_IDENTITY = "cc (Ubuntu 13.2.0-23ubuntu4) 13.2.0"


def _stage(recipe: NativeRecipe, build_tree: dict[str, Path], output: Path):
    return stage_bundle(
        build_tree,
        output,
        recipe=recipe,
        source_commit=recipe.upstream_commit,
        patch_series_digest=PATCH_DIGESTS,
        compiler_identity=COMPILER_IDENTITY,
        build_defines=dict(recipe.cmake_defines),
    )


def _paths(tmp_path: Path) -> RuntimePaths:
    root = tmp_path / "runtime"
    root.mkdir(parents=True, exist_ok=True)
    return RuntimePaths(tree=tmp_path, root=root)


def test_stage_writes_a_manifest_naming_every_target(tmp_path, recipe, build_tree):
    manifest = _stage(recipe, build_tree, tmp_path / "bundle.tar")
    assert {record.name for record in manifest.executables} == set(recipe.targets)
    assert manifest.compiler_identity == COMPILER_IDENTITY
    assert manifest.glibc_required == "GLIBC_2.34"
    assert manifest.executable("probe-server").dt_needed == ("libstdc++.so.6", "libc.so.6")
    assert manifest.executable("probe-cli").glibc_required == "GLIBC_2.14"
    assert dict(manifest.cmake_defines) == dict(recipe.cmake_defines)
    assert [member.patch for member in manifest.patch_series] == sorted(PATCH_DIGESTS)


def test_stage_is_deterministic_over_two_runs(tmp_path, recipe, build_tree):
    first = tmp_path / "one.tar"
    second = tmp_path / "two.tar"
    _stage(recipe, build_tree, first)
    _stage(recipe, build_tree, second)
    assert first.read_bytes() == second.read_bytes()


def test_stage_refuses_a_build_tree_that_is_not_the_declared_target_set(
    tmp_path, recipe, build_tree
):
    del build_tree["probe-cli"]
    with pytest.raises(NativeBundleError, match="omits probe-cli"):
        _stage(recipe, build_tree, tmp_path / "bundle.tar")


def test_stage_refuses_defines_the_recipe_does_not_declare(tmp_path, recipe, build_tree):
    defines = dict(recipe.cmake_defines)
    defines["GGML_VULKAN"] = "OFF"
    with pytest.raises(NativeBundleError, match="GGML_VULKAN"):
        stage_bundle(
            build_tree,
            tmp_path / "bundle.tar",
            recipe=recipe,
            source_commit=recipe.upstream_commit,
            patch_series_digest=PATCH_DIGESTS,
            compiler_identity=COMPILER_IDENTITY,
            build_defines=defines,
        )


def test_verify_accepts_a_freshly_staged_bundle(tmp_path, recipe, build_tree):
    bundle = tmp_path / "bundle.tar"
    staged = _stage(recipe, build_tree, bundle)
    assert verify_bundle(bundle) == staged


def test_verify_accepts_a_gzip_bundle(tmp_path, recipe, build_tree):
    bundle = tmp_path / "bundle.tar.gz"
    staged = _stage(recipe, build_tree, bundle)
    assert verify_bundle(bundle).bundle_sha256 == staged.bundle_sha256


def _rewrite_bundle(source: Path, destination: Path, *, drop=(), replace=None, add=None) -> Path:
    """Copy a bundle member by member, applying one tamper, so the tar stays well formed."""
    with tarfile.open(source, "r:*") as reader, tarfile.open(destination, "w") as writer:
        for member in reader.getmembers():
            if member.name in drop:
                continue
            handle = reader.extractfile(member)
            assert handle is not None
            payload = handle.read()
            if replace is not None and member.name in replace:
                payload = replace[member.name]
                member.size = len(payload)
            writer.addfile(member, io.BytesIO(payload))
        for name, payload in (add or {}).items():
            info = tarfile.TarInfo(name)
            info.size = len(payload)
            writer.addfile(info, io.BytesIO(payload))
    return destination


def test_verify_refuses_a_member_whose_bytes_changed(tmp_path, recipe, build_tree):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    tampered = _rewrite_bundle(
        bundle,
        tmp_path / "tampered.tar",
        replace={"bin/probe-cli": _build_elf64(needed=["libc.so.6", "libz.so.1"])},
    )
    with pytest.raises(NativeBundleError, match="bytes, manifest states|hashes to"):
        verify_bundle(tampered)


def _edit_manifest(bundle: Path, destination: Path, edit) -> Path:
    with tarfile.open(bundle, "r:*") as archive:
        handle = archive.extractfile(MANIFEST_NAME)
        assert handle is not None
        document = json.loads(handle.read())
    edit(document)
    edited = (json.dumps(document, indent=2, sort_keys=True) + "\n").encode()
    return _rewrite_bundle(bundle, destination, replace={MANIFEST_NAME: edited})


@pytest.mark.parametrize(
    ("field", "edit"),
    [
        ("cmake_defines", lambda doc: doc["cmake_defines"].__setitem__("GGML_VULKAN", "OFF")),
        ("compiler_identity", lambda doc: doc.__setitem__("compiler_identity", "cc (other) 1.0")),
        ("upstream_commit", lambda doc: doc.__setitem__("upstream_commit", "0" * 40)),
        ("profile", lambda doc: doc.__setitem__("profile", "raven2-vulkan-production")),
        ("patch_series_sha256", lambda doc: doc.__setitem__("patch_series_sha256", "f" * 64)),
        ("glibc_required", lambda doc: doc.__setitem__("glibc_required", "GLIBC_2.17")),
    ],
)
def test_verify_refuses_a_manifest_provenance_field_that_was_edited(
    tmp_path, recipe, build_tree, field, edit
):
    """`bundle_sha256` covers the member bytes alone, so `manifest_sha256` is
    what makes the recorded build unforgeable; each field below is one claim a
    downstream reader would otherwise take on trust."""
    bundle = _stage_to(tmp_path, recipe, build_tree)
    tampered = _edit_manifest(bundle, tmp_path / f"tampered-{field}.tar", edit)
    with pytest.raises(NativeBundleError, match="recomputes to"):
        verify_bundle(tampered)


def test_install_refuses_a_bundle_whose_manifest_was_edited(tmp_path, recipe, build_tree):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    tampered = _edit_manifest(
        bundle,
        tmp_path / "tampered.tar",
        lambda doc: doc["cmake_defines"].__setitem__("GGML_VULKAN", "OFF"),
    )
    with pytest.raises(NativeBundleError, match="recomputes to"):
        install_bundle(_paths(tmp_path), tampered, expected_sha256=None)
    assert not (_paths(tmp_path).root / recipe.install_prefix).exists()


def test_verify_refuses_a_manifest_whose_bundle_digest_was_edited(tmp_path, recipe, build_tree):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    tampered = _edit_manifest(
        bundle, tmp_path / "tampered.tar", lambda doc: doc.__setitem__("bundle_sha256", "d" * 64)
    )
    with pytest.raises(NativeBundleError, match="bundle digest recomputes to"):
        verify_bundle(tampered)


def test_verify_refuses_a_manifest_whose_recorded_closure_was_edited(tmp_path, recipe, build_tree):
    def edit(document):
        for entry in document["executables"]:
            if entry["name"] == "probe-cli":
                entry["dt_needed"] = ["libc.so.6", "libinvented.so.1"]

    bundle = _stage_to(tmp_path, recipe, build_tree)
    tampered = _edit_manifest(bundle, tmp_path / "tampered.tar", edit)
    with pytest.raises(NativeBundleError, match="manifest states"):
        verify_bundle(tampered)


def test_verify_refuses_a_bundle_missing_a_member(tmp_path, recipe, build_tree):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    tampered = _rewrite_bundle(bundle, tmp_path / "tampered.tar", drop=("bin/probe-cli",))
    with pytest.raises(NativeBundleError, match="omits members the manifest names"):
        verify_bundle(tampered)


def test_verify_refuses_a_bundle_carrying_an_undeclared_member(tmp_path, recipe, build_tree):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    tampered = _rewrite_bundle(bundle, tmp_path / "tampered.tar", add={"bin/extra": b"payload"})
    with pytest.raises(NativeBundleError, match="member the manifest omits"):
        verify_bundle(tampered)


def test_verify_refuses_a_bundle_without_a_manifest(tmp_path, recipe, build_tree):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    tampered = _rewrite_bundle(bundle, tmp_path / "tampered.tar", drop=(MANIFEST_NAME,))
    with pytest.raises(NativeBundleError, match="carries no native-manifest.json"):
        verify_bundle(tampered)


def _stage_to(tmp_path: Path, recipe: NativeRecipe, build_tree: dict[str, Path]) -> Path:
    bundle = tmp_path / "bundle.tar"
    _stage(recipe, build_tree, bundle)
    return bundle


def test_install_places_the_bundle_under_its_digest_and_links_the_bin_names(
    tmp_path, recipe, build_tree
):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    paths = _paths(tmp_path)
    manifest = verify_bundle(bundle)
    installed = install_bundle(paths, bundle, expected_sha256=manifest.bundle_sha256)

    assert installed.root == paths.root / recipe.install_prefix / manifest.bundle_sha256
    for name in recipe.targets:
        executable = installed.executable_path(name)
        assert executable.is_file()
        assert executable.stat().st_mode & 0o111
        link = paths["qwen_home_bin"] / name
        assert link.is_symlink()
        assert not os.path.isabs(os.readlink(link))
        assert link.resolve() == executable.resolve()
    assert (installed.root / MANIFEST_NAME).is_file()


def test_install_is_idempotent_over_one_digest(tmp_path, recipe, build_tree):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    paths = _paths(tmp_path)
    first = install_bundle(paths, bundle, expected_sha256=None)
    second = install_bundle(paths, bundle, expected_sha256=None)
    assert first.root == second.root
    staging = paths["qwen_home_cache"] / "native-staging"
    assert not staging.exists() or not list(staging.iterdir())


def test_install_refuses_a_digest_directory_holding_a_different_tree(tmp_path, recipe, build_tree):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    paths = _paths(tmp_path)
    manifest = verify_bundle(bundle)
    occupied = paths.root / recipe.install_prefix / manifest.bundle_sha256
    occupied.mkdir(parents=True)
    (occupied / MANIFEST_NAME).write_bytes(b"{}")
    with pytest.raises(NativeBundleError, match="already holds a different tree"):
        install_bundle(paths, bundle, expected_sha256=None)


def test_install_refuses_a_bundle_whose_digest_is_not_the_expected_one(
    tmp_path, recipe, build_tree
):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    with pytest.raises(NativeBundleError, match="caller expected"):
        install_bundle(_paths(tmp_path), bundle, expected_sha256="e" * 64)


def test_installed_bundles_enumerates_what_the_store_holds(tmp_path, recipe, build_tree):
    bundle = _stage_to(tmp_path, recipe, build_tree)
    paths = _paths(tmp_path)
    assert installed_bundles(paths) == ()
    installed = install_bundle(paths, bundle, expected_sha256=None)
    found = installed_bundles(paths)
    assert len(found) == 1
    assert found[0].root == installed.root
    assert found[0].digest == installed.digest


def test_installed_bundles_ignores_a_directory_carrying_no_manifest(tmp_path, recipe, build_tree):
    paths = _paths(tmp_path)
    (paths.root / "opt" / "llama.cpp" / "build-qwen-vulkan").mkdir(parents=True)
    assert installed_bundles(paths) == ()


def test_a_bundle_requiring_a_newer_glibc_refuses_before_install(tmp_path, recipe, build_tree):
    build_tree["probe-server"] = _write_elf(
        build_tree["probe-server"],
        needed=["libc.so.6"],
        verneed=[("libc.so.6", ["GLIBC_2.99"])],
    )
    manifest = _stage(recipe, build_tree, tmp_path / "bundle.tar")
    assert manifest.glibc_required == "GLIBC_2.99"
    with pytest.raises(NativeBundleError, match="host provides GLIBC_2.39"):
        require_host_glibc(manifest, host_glibc="GLIBC_2.39")


def test_a_bundle_within_the_hosts_glibc_passes(tmp_path, recipe, build_tree):
    manifest = _stage(recipe, build_tree, tmp_path / "bundle.tar")
    require_host_glibc(manifest, host_glibc="GLIBC_2.39")


def test_store_root_refuses_a_manifest_prefix_of_another_shape(tmp_path, recipe, build_tree):
    """The prefix reaches `_store_root` through a verified manifest, and the
    check restates the recipe rule at the point that turns it into a path."""
    manifest = _stage(recipe, build_tree, tmp_path / "bundle.tar")
    paths = _paths(tmp_path)
    assert _store_root(paths, manifest) == paths.root / "opt" / "llama"
    for prefix, reason in (
        ("opt/native/llama", "not opt/<engine>"),
        ("/opt/llama", "not a relative path"),
        ("../llama", "not a relative path"),
    ):
        with pytest.raises(NativeBundleError, match=reason):
            _store_root(paths, dataclasses.replace(manifest, install_prefix=prefix))


def test_manifest_round_trips_through_json(tmp_path, recipe, build_tree):
    manifest = _stage(recipe, build_tree, tmp_path / "bundle.tar")
    assert manifest_from_json(manifest_to_json(manifest)) == manifest
