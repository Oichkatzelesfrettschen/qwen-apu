"""The no-sudo prebuilt native path: stage a bundle, verify it, install it content-addressed.

A native bundle is one tar carrying the executables a recipe in
config/native-builds.toml names plus a `native-manifest.json` that states what
produced them. `stage_bundle` writes the pair from a finished build tree,
`verify_bundle` re-derives every digest in the manifest from the tar itself, and
`install_bundle` stages the contents under the runtime root's cache and moves
them into `<install prefix>/<bundle digest>/` with one `os.replace`, then points
`<bin>/<target>` at the installed executables. Every path stays under the
runtime root, so the whole path runs as the serving user.

The manifest records what the host must supply before a launch can succeed:
`dt_needed` and `interp` per executable, parsed out of the ELF program and
dynamic headers here rather than through `ldd` (which runs the loader) or
`readelf` (which is a binutils dependency the appliance does not carry), and
`glibc_required`, the highest `GLIBC_x.y` version the `.gnu.version_r` table
names. A host whose own glibc is older cannot resolve those symbols, so
`install_bundle` refuses on that comparison before any binary is placed where a
launch would find it.

Two ELF details decide whether this parser is right on a real binary.
`DT_STRTAB` holds a virtual address rather than a file offset, so it resolves
through the `PT_LOAD` segment covering it; a position-dependent layout happens
to make the two equal and hides the bug. The `.gnu.version_r` offsets
(`vn_aux`, `vn_next`, `vna_next`) count from the start of their own entry rather
than from the section, so the walk adds them to the running entry position.
"""

from __future__ import annotations

import io
import json
import os
import re
import secrets
import struct
import tarfile
from collections.abc import Iterator, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType, TracebackType
from typing import BinaryIO, Literal

from qwen_apu.config.native import NativeRecipe
from qwen_apu.install.artifacts import (
    ArtifactStoreError,
    atomic_install,
    digest_bytes,
    digest_file,
    remove_tree,
    require_digest,
    store_path,
)
from qwen_apu.runtime.paths import RuntimePaths

MANIFEST_NAME = "native-manifest.json"
MANIFEST_SCHEMA = 1
BUNDLE_BIN_PREFIX = "bin"
STAGING_DIRECTORY_NAME = "native-staging"

_ELF_MAGIC = b"\x7fELF"
_ELFCLASS64 = 2
_ELFDATA2LSB = 1
_ELFDATA2MSB = 2

_PT_LOAD = 1
_PT_DYNAMIC = 2
_PT_INTERP = 3

_DT_NULL = 0
_DT_NEEDED = 1
_DT_STRTAB = 5
_DT_STRSZ = 10
_DT_SONAME = 14

_SHT_GNU_VERNEED = 0x6FFFFFFE

_ELF_HEADER_STRUCT = "HHIQQQIHHHHHH"
_PROGRAM_HEADER_STRUCT = "IIQQQQQQ"
_SECTION_HEADER_STRUCT = "IIQQQQIIQQ"
_DYNAMIC_ENTRY_STRUCT = "qQ"
_VERNEED_STRUCT = "HHIII"
_VERNAUX_STRUCT = "IHHII"

_GLIBC_VERSION = re.compile(r"^GLIBC_([0-9]+)\.([0-9]+)$")
_HOST_GLIBC = re.compile(r"([0-9]+)\.([0-9]+)")

# The loader's own search path, read from the files that declare it. The four
# trailing directories are the loader's built-in defaults on a 64-bit Linux
# host; every other entry comes from the distribution's configuration.
_LD_SO_CONF_DIRECTORY = "/etc/ld.so.conf.d"  # appliance-path: named
_LD_SO_CONF = "/etc/ld.so.conf"  # appliance-path: named
_DEFAULT_LOADER_DIRECTORIES = (
    "/lib",  # appliance-path: named
    "/usr/lib",  # appliance-path: named
    "/lib64",  # appliance-path: named
    "/usr/lib64",  # appliance-path: named
)


class NativeBundleError(RuntimeError):
    """A bundle, its manifest, or the host it installs onto fails one stated check."""


class ElfFormatError(NativeBundleError):
    """A file the bundle path reads is not the ELF64 object its position claims."""


# ---------------------------------------------------------------------------
# ELF64 reading
# ---------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class _Segment:
    kind: int
    offset: int
    vaddr: int
    filesz: int
    memsz: int


@dataclass(frozen=True, slots=True)
class _Section:
    kind: int
    offset: int
    size: int
    link: int
    entsize: int


@dataclass(frozen=True, slots=True)
class Closure:
    """One executable's dynamic dependencies, as its own headers state them.

    `interp` is the `PT_INTERP` path, the loader the kernel starts for this
    file. `needed` is every `DT_NEEDED` soname in link order. `glibc_required`
    is the highest `GLIBC_x.y` version `.gnu.version_r` names, absent when the
    file references no versioned glibc symbol.
    """

    interp: str | None
    soname: str | None
    needed: tuple[str, ...]
    glibc_required: str | None


@dataclass(frozen=True, slots=True)
class ClosureResolution:
    """Which sonames a directory list resolves and which stay unresolved."""

    resolved: Mapping[str, Path]
    missing: tuple[str, ...]

    @property
    def satisfied(self) -> bool:
        return not self.missing


class _ElfReader:
    """Random access over one ELF64 image, over a file or a tar member stream."""

    def __init__(self, stream: BinaryIO, *, label: str) -> None:
        self._stream = stream
        self._label = label
        ident = self._read_at(0, 16)
        if ident[:4] != _ELF_MAGIC:
            raise ElfFormatError(f"{label}: no ELF magic")
        if ident[4] != _ELFCLASS64:
            raise ElfFormatError(f"{label}: ELF class {ident[4]} is not ELF64")
        if ident[5] == _ELFDATA2LSB:
            self._byte_order = "<"
        elif ident[5] == _ELFDATA2MSB:
            self._byte_order = ">"
        else:
            raise ElfFormatError(f"{label}: ELF data encoding {ident[5]} is neither LSB nor MSB")
        header = struct.unpack(
            self._byte_order + _ELF_HEADER_STRUCT,
            self._read_at(16, struct.calcsize(_ELF_HEADER_STRUCT)),
        )
        # The header fields after e_ident are e_type, e_machine, e_version,
        # e_entry, e_phoff, e_shoff, e_flags, e_ehsize, e_phentsize, e_phnum,
        # e_shentsize, e_shnum, e_shstrndx, so the table offsets are 4 and 5 and
        # the entry sizes and counts follow e_ehsize at 7.
        self._phoff = int(header[4])
        self._shoff = int(header[5])
        self._phentsize = int(header[8])
        self._phnum = int(header[9])
        self._shentsize = int(header[10])
        self._shnum = int(header[11])

    @property
    def byte_order(self) -> str:
        """`<` or `>`, from EI_DATA; every struct read in this class carries it."""
        return self._byte_order

    def _read_at(self, offset: int, size: int) -> bytes:
        if offset < 0 or size < 0:
            raise ElfFormatError(f"{self._label}: negative read at {offset} for {size} bytes")
        self._stream.seek(offset)
        payload = self._stream.read(size)
        if len(payload) != size:
            raise ElfFormatError(
                f"{self._label}: read at {offset} returned {len(payload)} of {size} bytes"
            )
        return payload

    def segments(self) -> tuple[_Segment, ...]:
        if self._phoff == 0 or self._phnum == 0:
            return ()
        entry_size = struct.calcsize(_PROGRAM_HEADER_STRUCT)
        if self._phentsize != entry_size:
            raise ElfFormatError(
                f"{self._label}: program header entry is {self._phentsize} bytes, "
                f"expected {entry_size}"
            )
        found = []
        for index in range(self._phnum):
            fields = struct.unpack(
                self._byte_order + _PROGRAM_HEADER_STRUCT,
                self._read_at(self._phoff + index * entry_size, entry_size),
            )
            found.append(
                _Segment(
                    kind=int(fields[0]),
                    offset=int(fields[2]),
                    vaddr=int(fields[3]),
                    filesz=int(fields[5]),
                    memsz=int(fields[6]),
                )
            )
        return tuple(found)

    def sections(self) -> tuple[_Section, ...]:
        if self._shoff == 0 or self._shnum == 0:
            return ()
        entry_size = struct.calcsize(_SECTION_HEADER_STRUCT)
        if self._shentsize != entry_size:
            raise ElfFormatError(
                f"{self._label}: section header entry is {self._shentsize} bytes, "
                f"expected {entry_size}"
            )
        found = []
        for index in range(self._shnum):
            fields = struct.unpack(
                self._byte_order + _SECTION_HEADER_STRUCT,
                self._read_at(self._shoff + index * entry_size, entry_size),
            )
            found.append(
                _Section(
                    kind=int(fields[1]),
                    offset=int(fields[4]),
                    size=int(fields[5]),
                    link=int(fields[6]),
                    entsize=int(fields[9]),
                )
            )
        return tuple(found)

    def offset_of_vaddr(self, vaddr: int, segments: Sequence[_Segment]) -> int:
        """Map a virtual address into a file offset through the PT_LOAD covering it.

        `DT_STRTAB` and the dynamic string table it names are addresses in the
        loaded image; the bytes live wherever the segment carrying that address
        was read from.
        """
        for segment in segments:
            if segment.kind != _PT_LOAD:
                continue
            if segment.vaddr <= vaddr < segment.vaddr + segment.filesz:
                return vaddr - segment.vaddr + segment.offset
        raise ElfFormatError(f"{self._label}: no PT_LOAD segment covers address {vaddr:#x}")

    def string_at(self, table_offset: int, table_size: int, index: int) -> str:
        if index >= table_size:
            raise ElfFormatError(
                f"{self._label}: string index {index} falls outside a {table_size}-byte table"
            )
        payload = self._read_at(table_offset + index, min(4096, table_size - index))
        end = payload.find(b"\0")
        if end < 0:
            raise ElfFormatError(f"{self._label}: unterminated string at table index {index}")
        return payload[:end].decode("utf-8", errors="replace")

    def read_bytes(self, offset: int, size: int) -> bytes:
        return self._read_at(offset, size)


def _read_interpreter(reader: _ElfReader, segments: Sequence[_Segment]) -> str | None:
    for segment in segments:
        if segment.kind == _PT_INTERP and segment.filesz:
            payload = reader.read_bytes(segment.offset, segment.filesz)
            return payload.split(b"\0", 1)[0].decode("utf-8", errors="replace")
    return None


def _read_dynamic(
    reader: _ElfReader, segments: Sequence[_Segment]
) -> tuple[tuple[str, ...], str | None]:
    """`DT_NEEDED` sonames in link order and `DT_SONAME`, or empty when PT_DYNAMIC is absent.

    A statically linked executable carries no PT_DYNAMIC, which is an empty
    closure rather than a malformed file.
    """
    dynamic = next((segment for segment in segments if segment.kind == _PT_DYNAMIC), None)
    if dynamic is None or dynamic.filesz == 0:
        return (), None
    entry_size = struct.calcsize(_DYNAMIC_ENTRY_STRUCT)
    payload = reader.read_bytes(dynamic.offset, dynamic.filesz)
    needed_indices: list[int] = []
    soname_index: int | None = None
    strtab_vaddr: int | None = None
    strtab_size: int | None = None
    for position in range(0, len(payload) - entry_size + 1, entry_size):
        tag, value = struct.unpack(
            reader.byte_order + _DYNAMIC_ENTRY_STRUCT,
            payload[position : position + entry_size],
        )
        if tag == _DT_NULL:
            break
        if tag == _DT_NEEDED:
            needed_indices.append(int(value))
        elif tag == _DT_SONAME:
            soname_index = int(value)
        elif tag == _DT_STRTAB:
            strtab_vaddr = int(value)
        elif tag == _DT_STRSZ:
            strtab_size = int(value)
    if not needed_indices and soname_index is None:
        return (), None
    if strtab_vaddr is None or strtab_size is None:
        raise ElfFormatError("dynamic section names DT_NEEDED without DT_STRTAB and DT_STRSZ")
    table_offset = reader.offset_of_vaddr(strtab_vaddr, segments)
    needed = tuple(reader.string_at(table_offset, strtab_size, index) for index in needed_indices)
    soname = (
        reader.string_at(table_offset, strtab_size, soname_index)
        if soname_index is not None
        else None
    )
    return needed, soname


def _read_glibc_required(reader: _ElfReader) -> str | None:
    """The highest `GLIBC_x.y` version `.gnu.version_r` names.

    The table also names `GLIBC_ABI_DT_RELR`, `GCC_3.0`, `CXXABI_1.3.x`, and
    `GLIBCXX_3.4.x`, none of which carry a glibc release number, so the walk
    keeps the names matching `GLIBC_<major>.<minor>` and compares them as
    integer pairs: `GLIBC_2.34` is newer than `GLIBC_2.9`, which the strings
    order the other way.
    """
    sections = reader.sections()
    verneed = next((section for section in sections if section.kind == _SHT_GNU_VERNEED), None)
    if verneed is None or verneed.size == 0:
        return None
    if verneed.link >= len(sections):
        raise ElfFormatError(f".gnu.version_r links to section {verneed.link}, which is absent")
    strings = sections[verneed.link]
    payload = reader.read_bytes(verneed.offset, verneed.size)
    verneed_size = struct.calcsize(_VERNEED_STRUCT)
    vernaux_size = struct.calcsize(_VERNAUX_STRUCT)
    byte_order = reader.byte_order

    highest: tuple[int, int] | None = None
    entry_position = 0
    while entry_position + verneed_size <= len(payload):
        _version, count, _file, aux, nxt = struct.unpack(
            byte_order + _VERNEED_STRUCT,
            payload[entry_position : entry_position + verneed_size],
        )
        aux_position = entry_position + int(aux)
        for _ in range(int(count)):
            if aux_position + vernaux_size > len(payload):
                break
            _hash, _flags, _other, name, aux_next = struct.unpack(
                byte_order + _VERNAUX_STRUCT,
                payload[aux_position : aux_position + vernaux_size],
            )
            text = reader.string_at(strings.offset, strings.size, int(name))
            match = _GLIBC_VERSION.match(text)
            if match is not None:
                version = (int(match.group(1)), int(match.group(2)))
                if highest is None or version > highest:
                    highest = version
            if aux_next == 0:
                break
            aux_position += int(aux_next)
        if nxt == 0:
            break
        entry_position += int(nxt)
    if highest is None:
        return None
    return f"GLIBC_{highest[0]}.{highest[1]}"


def closure_from_stream(stream: BinaryIO, *, label: str) -> Closure:
    """Parse one ELF64 image's interpreter, sonames, and glibc version floor."""
    reader = _ElfReader(stream, label=label)
    segments = reader.segments()
    needed, soname = _read_dynamic(reader, segments)
    return Closure(
        interp=_read_interpreter(reader, segments),
        soname=soname,
        needed=needed,
        glibc_required=_read_glibc_required(reader),
    )


def shared_library_closure(elf: Path) -> Closure:
    """The dynamic closure one executable declares, read from its own headers."""
    with elf.open("rb") as handle:
        return closure_from_stream(handle, label=str(elf))


def _conf_directories(path: Path) -> Iterator[str]:
    """Every absolute directory one ld.so configuration file lists.

    An `include` line names further files; the caller expands the glob
    directory itself, so the parse keeps the plain directory entries.
    """
    if not path.is_file():
        return
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line or line.startswith("include"):
            continue
        if line.startswith("/"):
            yield line


def default_search_dirs() -> tuple[Path, ...]:
    """The directories the dynamic loader searches, in the order it reads them.

    `/etc/ld.so.conf` and every `*.conf` under `/etc/ld.so.conf.d` supply the
    distribution's entries, and the four built-in 64-bit defaults follow. Only
    directories that exist are returned, so a resolution failure names a
    missing library rather than a missing directory.
    """
    named: list[str] = list(_conf_directories(Path(_LD_SO_CONF)))
    conf_directory = Path(_LD_SO_CONF_DIRECTORY)
    if conf_directory.is_dir():
        for conf in sorted(conf_directory.glob("*.conf")):
            named.extend(_conf_directories(conf))
    named.extend(_DEFAULT_LOADER_DIRECTORIES)
    seen: set[str] = set()
    ordered: list[Path] = []
    for entry in named:
        if entry in seen:
            continue
        seen.add(entry)
        candidate = Path(entry)
        if candidate.is_dir():
            ordered.append(candidate)
    return tuple(ordered)


def closure_satisfied(
    closure: Closure, search_dirs: Sequence[Path] | None = None
) -> ClosureResolution:
    """Resolve every `DT_NEEDED` soname against a directory list, first match winning.

    The interpreter joins the resolution when the closure names one, since a
    bundle whose `PT_INTERP` is absent from the host starts no process at all.
    """
    directories = tuple(search_dirs) if search_dirs is not None else default_search_dirs()
    resolved: dict[str, Path] = {}
    missing: list[str] = []
    for soname in closure.needed:
        for directory in directories:
            candidate = directory / soname
            if candidate.exists():
                resolved[soname] = candidate
                break
        else:
            missing.append(soname)
    if closure.interp is not None:
        interpreter = Path(closure.interp)
        if interpreter.exists():
            resolved[closure.interp] = interpreter
        else:
            missing.append(closure.interp)
    return ClosureResolution(resolved=MappingProxyType(resolved), missing=tuple(missing))


# ---------------------------------------------------------------------------
# Bundle manifest
# ---------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class PatchMember:
    """One patch the series applied, at the digest the build read it from."""

    patch: str
    sha256: str


@dataclass(frozen=True, slots=True)
class ExecutableRecord:
    """One executable in the bundle: its size, its digest, and what it needs to run."""

    name: str
    bytes: int
    sha256: str
    dt_needed: tuple[str, ...]
    interp: str | None
    glibc_required: str | None

    @property
    def member_name(self) -> str:
        return f"{BUNDLE_BIN_PREFIX}/{self.name}"


@dataclass(frozen=True, slots=True)
class BundleManifest:
    """Everything a bundle states about the build that produced it."""

    schema: int
    recipe: str
    profile: str
    install_prefix: str
    upstream_commit: str
    source_commit: str
    patch_series: tuple[PatchMember, ...]
    patch_series_sha256: str
    cmake_defines: Mapping[str, str]
    compiler_identity: str
    glibc_required: str | None
    executables: tuple[ExecutableRecord, ...]
    bundle_sha256: str
    manifest_sha256: str

    def executable(self, name: str) -> ExecutableRecord:
        for record in self.executables:
            if record.name == name:
                return record
        raise NativeBundleError(f"bundle names no executable {name}")


def _patch_series_digest(members: Sequence[PatchMember]) -> str:
    payload = "".join(f"{member.patch}\0{member.sha256}\n" for member in members)
    return digest_bytes(payload.encode("utf-8"))


def _bundle_digest(records: Sequence[ExecutableRecord]) -> str:
    """One digest over the sorted member digests, which is the bundle's store key."""
    payload = "".join(
        f"{record.member_name}\0{record.sha256}\n"
        for record in sorted(records, key=lambda entry: entry.member_name)
    )
    return digest_bytes(payload.encode("utf-8"))


def _provenance_digest(
    *,
    recipe: str,
    profile: str,
    install_prefix: str,
    upstream_commit: str,
    source_commit: str,
    patch_series_sha256: str,
    cmake_defines: Mapping[str, str],
    compiler_identity: str,
    glibc_required: str | None,
    bundle_sha256: str,
) -> str:
    """One digest over every claim the manifest makes about the build.

    `bundle_sha256` covers the member bytes and nothing else, so the recipe,
    the pinned commits, the cmake defines, the compiler, and the glibc floor
    would otherwise be editable text: a manifest rewritten to claim
    `GGML_VULKAN=OFF` would install and enumerate as the build it names. This
    digest closes that, and it includes `bundle_sha256` so the two statements
    bind to each other rather than standing apart.
    """
    document = {
        "recipe": recipe,
        "profile": profile,
        "install_prefix": install_prefix,
        "upstream_commit": upstream_commit,
        "source_commit": source_commit,
        "patch_series_sha256": patch_series_sha256,
        "cmake_defines": dict(cmake_defines),
        "compiler_identity": compiler_identity,
        "glibc_required": glibc_required,
        "bundle_sha256": bundle_sha256,
    }
    return digest_bytes(json.dumps(document, sort_keys=True, separators=(",", ":")).encode("utf-8"))


def _manifest_digest_of(manifest: BundleManifest) -> str:
    return _provenance_digest(
        recipe=manifest.recipe,
        profile=manifest.profile,
        install_prefix=manifest.install_prefix,
        upstream_commit=manifest.upstream_commit,
        source_commit=manifest.source_commit,
        patch_series_sha256=manifest.patch_series_sha256,
        cmake_defines=manifest.cmake_defines,
        compiler_identity=manifest.compiler_identity,
        glibc_required=manifest.glibc_required,
        bundle_sha256=manifest.bundle_sha256,
    )


def manifest_to_json(manifest: BundleManifest) -> bytes:
    """Serialize a manifest with sorted keys and a trailing newline, so two
    stagings of one build produce byte-identical manifests."""
    document = {
        "schema": manifest.schema,
        "recipe": manifest.recipe,
        "profile": manifest.profile,
        "install_prefix": manifest.install_prefix,
        "upstream_commit": manifest.upstream_commit,
        "source_commit": manifest.source_commit,
        "patch_series": [
            {"patch": member.patch, "sha256": member.sha256} for member in manifest.patch_series
        ],
        "patch_series_sha256": manifest.patch_series_sha256,
        "cmake_defines": dict(manifest.cmake_defines),
        "compiler_identity": manifest.compiler_identity,
        "glibc_required": manifest.glibc_required,
        "executables": [
            {
                "name": record.name,
                "bytes": record.bytes,
                "sha256": record.sha256,
                "dt_needed": list(record.dt_needed),
                "interp": record.interp,
                "glibc_required": record.glibc_required,
            }
            for record in manifest.executables
        ],
        "bundle_sha256": manifest.bundle_sha256,
        "manifest_sha256": manifest.manifest_sha256,
    }
    return (json.dumps(document, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _require_type[T](value: object, kind: type[T], *, label: str) -> T:
    if not isinstance(value, kind):
        raise NativeBundleError(f"{label} is {type(value).__name__}, expected {kind.__name__}")
    return value


def _optional_str(value: object, *, label: str) -> str | None:
    if value is None:
        return None
    return _require_type(value, str, label=label)


def manifest_from_json(payload: bytes) -> BundleManifest:
    """Parse a manifest and refuse a field whose shape the install path relies on."""
    try:
        document = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise NativeBundleError(f"{MANIFEST_NAME} is not UTF-8 JSON: {error}") from error
    document = _require_type(document, dict, label=MANIFEST_NAME)
    schema = _require_type(document.get("schema"), int, label="schema")
    if schema != MANIFEST_SCHEMA:
        raise NativeBundleError(f"manifest schema is {schema}, expected {MANIFEST_SCHEMA}")

    patch_series = tuple(
        PatchMember(
            patch=_require_type(entry.get("patch"), str, label="patch_series[].patch"),
            sha256=require_digest(
                _require_type(entry.get("sha256"), str, label="patch_series[].sha256")
            ),
        )
        for entry in _require_type(document.get("patch_series"), list, label="patch_series")
    )
    defines_table = _require_type(document.get("cmake_defines"), dict, label="cmake_defines")
    cmake_defines = {
        _require_type(key, str, label="cmake_defines key"): _require_type(
            value, str, label=f"cmake_defines.{key}"
        )
        for key, value in defines_table.items()
    }
    executables = tuple(
        ExecutableRecord(
            name=_require_type(entry.get("name"), str, label="executables[].name"),
            bytes=_require_type(entry.get("bytes"), int, label="executables[].bytes"),
            sha256=require_digest(
                _require_type(entry.get("sha256"), str, label="executables[].sha256")
            ),
            dt_needed=tuple(
                _require_type(soname, str, label="executables[].dt_needed[]")
                for soname in _require_type(
                    entry.get("dt_needed"), list, label="executables[].dt_needed"
                )
            ),
            interp=_optional_str(entry.get("interp"), label="executables[].interp"),
            glibc_required=_optional_str(
                entry.get("glibc_required"), label="executables[].glibc_required"
            ),
        )
        for entry in _require_type(document.get("executables"), list, label="executables")
    )
    if not executables:
        raise NativeBundleError("manifest names no executable")

    return BundleManifest(
        schema=schema,
        recipe=_require_type(document.get("recipe"), str, label="recipe"),
        profile=_require_type(document.get("profile"), str, label="profile"),
        install_prefix=_require_type(document.get("install_prefix"), str, label="install_prefix"),
        upstream_commit=_require_type(
            document.get("upstream_commit"), str, label="upstream_commit"
        ),
        source_commit=_require_type(document.get("source_commit"), str, label="source_commit"),
        patch_series=patch_series,
        patch_series_sha256=require_digest(
            _require_type(document.get("patch_series_sha256"), str, label="patch_series_sha256")
        ),
        cmake_defines=MappingProxyType(cmake_defines),
        compiler_identity=_require_type(
            document.get("compiler_identity"), str, label="compiler_identity"
        ),
        glibc_required=_optional_str(document.get("glibc_required"), label="glibc_required"),
        executables=executables,
        bundle_sha256=require_digest(
            _require_type(document.get("bundle_sha256"), str, label="bundle_sha256")
        ),
        manifest_sha256=require_digest(
            _require_type(document.get("manifest_sha256"), str, label="manifest_sha256")
        ),
    )


# ---------------------------------------------------------------------------
# Staging
# ---------------------------------------------------------------------------


def _glibc_version(text: str | None) -> tuple[int, int] | None:
    if text is None:
        return None
    match = _GLIBC_VERSION.match(text)
    if match is None:
        raise NativeBundleError(f"not a GLIBC version string: {text}")
    return int(match.group(1)), int(match.group(2))


def _highest_glibc(records: Sequence[ExecutableRecord]) -> str | None:
    versions = [
        version
        for version in (_glibc_version(record.glibc_required) for record in records)
        if version is not None
    ]
    if not versions:
        return None
    highest = max(versions)
    return f"GLIBC_{highest[0]}.{highest[1]}"


def _tar_mode(output_tar: Path) -> Literal["w", "w:gz"]:
    """`.tar.gz` and `.tgz` write gzip, every other suffix writes an uncompressed tar."""
    suffixes = output_tar.suffixes
    if output_tar.name.endswith(".tar.gz") or output_tar.suffix == ".tgz":
        return "w:gz"
    if suffixes and suffixes[-1] not in {".tar"}:
        raise NativeBundleError(f"bundle name states no tar or tar.gz suffix: {output_tar.name}")
    return "w"


def _deterministic_member(name: str, size: int, mode: int) -> tarfile.TarInfo:
    """A member whose metadata carries no host identity, so one build yields one tar."""
    info = tarfile.TarInfo(name=name)
    info.size = size
    info.mode = mode
    info.mtime = 0
    info.uid = 0
    info.gid = 0
    info.uname = ""
    info.gname = ""
    info.type = tarfile.REGTYPE
    return info


def stage_bundle(
    build_tree_binaries: dict[str, Path],
    output_tar: Path,
    *,
    recipe: NativeRecipe,
    source_commit: str,
    patch_series_digest: Mapping[str, str],
    compiler_identity: str,
    build_defines: Mapping[str, str],
) -> BundleManifest:
    """Write one native bundle from a finished build tree and return its manifest.

    The recipe is binding rather than advisory: the executables offered must be
    exactly the targets it names, and `build_defines` must equal the defines it
    declares, so a tar can only describe a build the recipe states. Each
    executable's ELF headers supply `dt_needed`, `interp`, and the glibc floor,
    and the bundle digest over the sorted member digests becomes the store key
    the install writes under.
    """
    offered = set(build_tree_binaries)
    declared = set(recipe.targets)
    if offered != declared:
        extra = ", ".join(sorted(offered - declared)) or "-"
        absent = ", ".join(sorted(declared - offered)) or "-"
        raise NativeBundleError(
            f"[{recipe.name}] names targets {', '.join(recipe.targets)}; "
            f"the build tree offers extra {extra} and omits {absent}"
        )
    if dict(build_defines) != dict(recipe.cmake_defines):
        differing = sorted(
            key
            for key in set(build_defines) | set(recipe.cmake_defines)
            if build_defines.get(key) != recipe.cmake_defines.get(key)
        )
        raise NativeBundleError(
            f"[{recipe.name}] declares different cmake defines than the build used: "
            f"{', '.join(differing)}"
        )
    if not compiler_identity:
        raise NativeBundleError("compiler_identity is empty")

    records: list[ExecutableRecord] = []
    for name in recipe.targets:
        path = build_tree_binaries[name]
        if not path.is_file():
            raise NativeBundleError(f"build tree holds no {name}: {path}")
        closure = shared_library_closure(path)
        records.append(
            ExecutableRecord(
                name=name,
                bytes=path.stat().st_size,
                sha256=digest_file(path),
                dt_needed=closure.needed,
                interp=closure.interp,
                glibc_required=closure.glibc_required,
            )
        )

    patch_members = tuple(
        PatchMember(patch=patch, sha256=require_digest(patch_series_digest[patch]))
        for patch in sorted(patch_series_digest)
    )
    patch_series_sha256 = _patch_series_digest(patch_members)
    resolved_commit = require_digest(source_commit) if len(source_commit) == 64 else source_commit
    glibc_required = _highest_glibc(records)
    bundle_sha256 = _bundle_digest(records)
    manifest = BundleManifest(
        schema=MANIFEST_SCHEMA,
        recipe=recipe.name,
        profile=recipe.profile,
        install_prefix=recipe.install_prefix,
        upstream_commit=recipe.upstream_commit,
        source_commit=resolved_commit,
        patch_series=patch_members,
        patch_series_sha256=patch_series_sha256,
        cmake_defines=MappingProxyType(dict(build_defines)),
        compiler_identity=compiler_identity,
        glibc_required=glibc_required,
        executables=tuple(records),
        bundle_sha256=bundle_sha256,
        manifest_sha256=_provenance_digest(
            recipe=recipe.name,
            profile=recipe.profile,
            install_prefix=recipe.install_prefix,
            upstream_commit=recipe.upstream_commit,
            source_commit=resolved_commit,
            patch_series_sha256=patch_series_sha256,
            cmake_defines=build_defines,
            compiler_identity=compiler_identity,
            glibc_required=glibc_required,
            bundle_sha256=bundle_sha256,
        ),
    )

    output_tar.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(output_tar, _tar_mode(output_tar)) as archive:
        for record in sorted(records, key=lambda entry: entry.member_name):
            source = build_tree_binaries[record.name]
            with source.open("rb") as handle:
                archive.addfile(
                    _deterministic_member(record.member_name, record.bytes, 0o755), handle
                )
        payload = manifest_to_json(manifest)
        archive.addfile(
            _deterministic_member(MANIFEST_NAME, len(payload), 0o644), io.BytesIO(payload)
        )
    return manifest


# ---------------------------------------------------------------------------
# Verification and installation
# ---------------------------------------------------------------------------


def _require_safe_member(member: tarfile.TarInfo, *, allowed: Sequence[str]) -> None:
    """A bundle member is a regular file at one of the names the manifest states.

    An absolute path, a `..` component, a symbolic link, a hard link, and a
    device node all reach outside the staging directory, so the read refuses
    each by name rather than relying on an extraction helper's own policy.
    """
    if not member.isfile():
        raise NativeBundleError(f"bundle member {member.name} is not a regular file")
    name = member.name
    if name.startswith("/") or ".." in Path(name).parts:
        raise NativeBundleError(f"bundle member escapes the bundle root: {name}")
    if name not in allowed:
        raise NativeBundleError(f"bundle carries a member the manifest omits: {name}")


def _read_manifest(archive: tarfile.TarFile) -> BundleManifest:
    try:
        member = archive.getmember(MANIFEST_NAME)
    except KeyError as error:
        raise NativeBundleError(f"bundle carries no {MANIFEST_NAME}") from error
    handle = archive.extractfile(member)
    if handle is None:
        raise NativeBundleError(f"{MANIFEST_NAME} is not a readable regular member")
    with handle:
        return manifest_from_json(handle.read())


def verify_bundle(tar_path: Path) -> BundleManifest:
    """Re-derive every digest in the manifest from the tar and refuse any divergence.

    The member set must equal the manifest's executables plus the manifest
    itself, each member's size and sha256 must equal what the record states,
    each member's ELF headers must still state the recorded `dt_needed`,
    `interp`, and glibc floor, and the bundle digest must recompute from the
    member digests. A tar that passes has one identity for the rest of the
    install path to act on.
    """
    if not tar_path.is_file():
        raise NativeBundleError(f"bundle is unreadable: {tar_path}")
    with tarfile.open(tar_path, "r:*") as archive:
        manifest = _read_manifest(archive)
        allowed = [MANIFEST_NAME, *(record.member_name for record in manifest.executables)]
        present = []
        for member in archive.getmembers():
            _require_safe_member(member, allowed=allowed)
            present.append(member.name)
        if sorted(present) != sorted(allowed):
            absent = ", ".join(sorted(set(allowed) - set(present))) or "-"
            raise NativeBundleError(f"bundle omits members the manifest names: {absent}")

        for record in manifest.executables:
            member = archive.getmember(record.member_name)
            if member.size != record.bytes:
                raise NativeBundleError(
                    f"{record.member_name} holds {member.size} bytes, "
                    f"manifest states {record.bytes}"
                )
            handle = archive.extractfile(member)
            if handle is None:
                raise NativeBundleError(f"{record.member_name} is not a readable regular member")
            with handle:
                payload = handle.read()
            actual = digest_bytes(payload)
            if actual != record.sha256:
                raise NativeBundleError(
                    f"{record.member_name} hashes to {actual}, manifest states {record.sha256}"
                )
            closure = closure_from_stream(io.BytesIO(payload), label=record.member_name)
            if closure.needed != record.dt_needed:
                raise NativeBundleError(
                    f"{record.member_name} needs {list(closure.needed)}, "
                    f"manifest states {list(record.dt_needed)}"
                )
            if closure.interp != record.interp:
                raise NativeBundleError(
                    f"{record.member_name} names interpreter {closure.interp}, "
                    f"manifest states {record.interp}"
                )
            if closure.glibc_required != record.glibc_required:
                raise NativeBundleError(
                    f"{record.member_name} requires {closure.glibc_required}, "
                    f"manifest states {record.glibc_required}"
                )

    recomputed = _bundle_digest(manifest.executables)
    if recomputed != manifest.bundle_sha256:
        raise NativeBundleError(
            f"bundle digest recomputes to {recomputed}, manifest states {manifest.bundle_sha256}"
        )
    recomputed_series = _patch_series_digest(manifest.patch_series)
    if recomputed_series != manifest.patch_series_sha256:
        raise NativeBundleError(
            f"patch series digest recomputes to {recomputed_series}, "
            f"manifest states {manifest.patch_series_sha256}"
        )
    if _highest_glibc(manifest.executables) != manifest.glibc_required:
        raise NativeBundleError(
            f"bundle glibc floor recomputes to {_highest_glibc(manifest.executables)}, "
            f"manifest states {manifest.glibc_required}"
        )
    recomputed_provenance = _manifest_digest_of(manifest)
    if recomputed_provenance != manifest.manifest_sha256:
        raise NativeBundleError(
            f"manifest digest recomputes to {recomputed_provenance}, "
            f"manifest states {manifest.manifest_sha256}; the recorded build differs "
            "from the one the manifest claims"
        )
    return manifest


def host_glibc_version() -> str | None:
    """The host's own glibc release, as `GLIBC_x.y`, read through `os.confstr`.

    `CS_GNU_LIBC_VERSION` answers `glibc 2.39` on a glibc host and is absent on
    a C library that defines no such name, which the caller reports rather than
    guesses past.
    """
    try:
        reported = os.confstr("CS_GNU_LIBC_VERSION")
    except (ValueError, OSError):
        return None
    if not reported:
        return None
    match = _HOST_GLIBC.search(reported)
    if match is None:
        return None
    return f"GLIBC_{match.group(1)}.{match.group(2)}"


def require_host_glibc(manifest: BundleManifest, *, host_glibc: str | None) -> None:
    """Refuse an install whose bundle names a glibc newer than the host provides.

    The versioned symbols the executables reference exist only from the release
    the bundle names onward, so an older host resolves none of them and the
    failure would otherwise surface as a loader error at launch.
    """
    required = _glibc_version(manifest.glibc_required)
    if required is None:
        return
    reported = host_glibc if host_glibc is not None else host_glibc_version()
    if reported is None:
        raise NativeBundleError(
            f"bundle requires {manifest.glibc_required} and the host reports no glibc version"
        )
    available = _glibc_version(reported)
    if available is None or available < required:
        raise NativeBundleError(
            f"bundle requires {manifest.glibc_required} and the host provides {reported}"
        )


@dataclass(frozen=True, slots=True)
class InstalledBundle:
    """One bundle in the store: its digest directory and the manifest inside it."""

    root: Path
    manifest: BundleManifest

    @property
    def digest(self) -> str:
        return self.manifest.bundle_sha256

    def executable_path(self, name: str) -> Path:
        return self.root / BUNDLE_BIN_PREFIX / self.manifest.executable(name).name


class _StagingDirectory:
    """A unique directory under the runtime root's cache, removed on any failure."""

    def __init__(self, cache_root: Path) -> None:
        self.path = cache_root / STAGING_DIRECTORY_NAME / secrets.token_hex(16)
        self.path.mkdir(parents=True)
        self._kept = False

    def keep(self) -> None:
        self._kept = True

    def __enter__(self) -> _StagingDirectory:
        return self

    def __exit__(
        self,
        kind: type[BaseException] | None,
        value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        if not self._kept:
            remove_tree(self.path)


def _store_root(paths: RuntimePaths, manifest: BundleManifest) -> Path:
    """`<runtime root>/opt/<engine>`, refused when the prefix is any other shape.

    The prefix travels in the manifest rather than in a caller argument, so a
    bundle installs where the recipe that produced it declared. The two-
    component rule matches `qwen_apu.config.native._require_relative_prefix`
    and is what makes `installed_bundles` a complete reader of the store: an
    absolute, upward, or deeper path would install somewhere no enumeration
    reaches.
    """
    prefix = Path(manifest.install_prefix)
    if prefix.is_absolute() or ".." in prefix.parts:
        raise NativeBundleError(f"manifest install_prefix is not a relative path: {prefix}")
    if len(prefix.parts) != 2 or prefix.parts[0] != "opt":
        raise NativeBundleError(
            f"manifest install_prefix is not opt/<engine>, two components: {prefix}"
        )
    return paths.root / prefix


def _link_relative(link: Path, target: Path) -> None:
    """Point `<bin>/<name>` at the store entry through a relative path, atomically.

    A relative link keeps the whole runtime root movable: an operator who
    exports a different `QWEN_HOME` and copies the tree finds the links still
    resolving inside it.
    """
    link.parent.mkdir(parents=True, exist_ok=True)
    relative = os.path.relpath(target, link.parent)
    temporary = link.parent / f".{link.name}.{secrets.token_hex(8)}"
    os.symlink(relative, temporary)
    os.replace(temporary, link)


def install_bundle(
    paths: RuntimePaths,
    tar_path: Path,
    *,
    expected_sha256: str | None,
) -> InstalledBundle:
    """Verify a bundle, stage it under the cache, and move it into its digest directory.

    `expected_sha256` is the caller's independent statement of which bundle this
    is; a tar whose own digest differs is refused before anything is written.
    The staged tree carries the executables at mode 0755 and the manifest beside
    them, `atomic_install` renames it into `<install prefix>/<digest>/`, and
    `<bin>/<target>` then points at each executable, so a second install of the
    same digest re-points the links over an unchanged store entry.
    """
    manifest = verify_bundle(tar_path)
    if expected_sha256 is not None and manifest.bundle_sha256 != require_digest(expected_sha256):
        raise NativeBundleError(
            f"bundle hashes to {manifest.bundle_sha256}, caller expected {expected_sha256}"
        )
    require_host_glibc(manifest, host_glibc=None)

    final_dir = store_path(_store_root(paths, manifest), manifest.bundle_sha256)
    cache_root = paths["qwen_home_cache"]
    cache_root.mkdir(parents=True, exist_ok=True)
    with _StagingDirectory(cache_root) as staging:
        bin_dir = staging.path / BUNDLE_BIN_PREFIX
        bin_dir.mkdir()
        with tarfile.open(tar_path, "r:*") as archive:
            for record in manifest.executables:
                member = archive.getmember(record.member_name)
                handle = archive.extractfile(member)
                if handle is None:
                    raise NativeBundleError(
                        f"{record.member_name} is not a readable regular member"
                    )
                destination = bin_dir / record.name
                with handle, destination.open("wb") as sink:
                    while True:
                        chunk = handle.read(1024 * 1024)
                        if not chunk:
                            break
                        sink.write(chunk)
                destination.chmod(0o755)
        (staging.path / MANIFEST_NAME).write_bytes(manifest_to_json(manifest))
        try:
            outcome = atomic_install(staging.path, final_dir)
        except ArtifactStoreError as error:
            raise NativeBundleError(str(error)) from error
        if outcome.created:
            staging.keep()

    installed = InstalledBundle(root=final_dir, manifest=manifest)
    for record in manifest.executables:
        _link_relative(paths["qwen_home_bin"] / record.name, installed.executable_path(record.name))
    return installed


def installed_bundles(paths: RuntimePaths) -> tuple[InstalledBundle, ...]:
    """Every bundle the store holds, ordered by install prefix then digest.

    The scan reads `<opt>/<engine>/<digest>/native-manifest.json`, so a
    directory under `opt` that carries no manifest at that depth is another
    component's storage and stays out of the result.
    """
    opt_root = paths["qwen_home_opt"]
    if not opt_root.is_dir():
        return ()
    found: list[InstalledBundle] = []
    for engine in sorted(entry for entry in opt_root.iterdir() if entry.is_dir()):
        for candidate in sorted(entry for entry in engine.iterdir() if entry.is_dir()):
            manifest_path = candidate / MANIFEST_NAME
            if not manifest_path.is_file():
                continue
            manifest = manifest_from_json(manifest_path.read_bytes())
            if candidate.name != manifest.bundle_sha256:
                raise NativeBundleError(
                    f"{candidate} is named for a digest the manifest states as "
                    f"{manifest.bundle_sha256}"
                )
            found.append(InstalledBundle(root=candidate, manifest=manifest))
    return tuple(found)
