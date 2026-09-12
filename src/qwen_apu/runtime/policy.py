"""The llama-server argv remote/qwen-capacity-policy.sh assembles, as one plan.

`build_launch_plan` walks the shell script top to bottom and returns the
complete launch it would have exec'd: the server argv, the exec chain that
carries it through the Vulkan wrapper and the two exec guards, the environment
names the policy exports and unsets, and the receipt lines it prints. Order is
the contract. Each refusal names one input while the argv it would have
produced is still readable, and a check moved earlier or later changes which
refusal a defective launch meets, so the port keeps the script's own sequence
rather than hoisting validation into a block.

Two claims the script states about llama.cpp decide most of its shape. First,
`common_preset::merge` overwrites every child section's key with the router
argv's value of the same name, so router mode leaves depth, the cache triple,
submission geometry, the checkpoint count, the Q4_K formulation key, and both
LAN bounds off its own argv and takes them from each preset section instead;
the single-model path sets all seven from the registry row it launches.
Second, `server-context.cpp` applies `--n-predict` only where a request's own
`max_tokens` is `-1`, so the output bound reaches an unspecified request and
the page refuses an oversized explicit one.

Refusals raise `PolicyError`, whose `messages` carry the shell's own lines in
order and whose `status` carries its exit code. The preset validators
accumulate: the shell's AWK sets `rejected = 1` and continues, so one run
reports every defective section and this port collects the same lines before
raising once.

Environment variables this module reads, under the shell's own names, each an
explicit keyword of `build_launch_plan` carrying the shell's own default:

    QWEN_ROUTER                        router mode, default 0
    QWEN_BIND_HOST                     listen address, default 127.0.0.1
    QWEN_CORS_ORIGINS                  --cors-origins, default localhost
    QWEN_WEB_LAN                       LAN exposure marker, default 0
    QWEN_WEB_LAN_OPEN                  bearer-free LAN decision, default 0
    QWEN_APPROVED_MODEL_ID             descriptor-bound identity, five fields
    QWEN_APPROVED_MODEL_FILE           together or none at all
    QWEN_APPROVED_MODEL_DEVICE
    QWEN_APPROVED_MODEL_INODE
    QWEN_APPROVED_MODEL_BYTES
    QWEN_MODEL_REGISTRY                models.tsv, default remote/models.tsv
    QWEN_MODEL_ROOT                    weights root, default qwen_home_models
    QWEN_QUARANTINE_REGISTRY           default remote/quarantine.tsv
    QWEN_DRAFT_PAIRS                   default remote/draft-pairs.tsv
    QWEN_CTX_CHECKPOINT_LEDGER         default remote/ctx-checkpoints.tsv
    QWEN_LAN_MAX_PROMPT_TOKENS         combined budget, set with the next
    QWEN_LAN_MAX_OUTPUT_TOKENS         combined budget and --n-predict
    QWEN_CACHE_TYPE_K                  default: the registry row, else q8_0
    QWEN_CACHE_TYPE_V                  default: the registry row, else q4_0
    QWEN_FLASH_ATTN                    default: the registry row, else on
    QWEN_CACHE_OVERRIDE_CONTEXT_CEILING  required by a cache-triple override
    QWEN_BATCH_SIZE                    default: the registry row, else 128
    QWEN_UBATCH_SIZE                   default: the registry row, else 32
    QWEN_ROUTER_PRESETS                default $QWEN_HOME/state/router-presets.ini
    QWEN_ROUTER_PRESET_SHA256          launcher-bound preset digest
    QWEN_ROUTER_MAX                    --models-max, default 1
    QWEN_ROUTER_INCLUDE_QUARANTINE     research override, default 0
    QWEN_WEB_PROFILES                  web ledger the preset must bind
    QWEN_WEB_AUTHORIZER_READY          validator-gated admission, default 0
    QWEN_BUNDLE_Q4K_POLICY             '', registry, -, legacy, or a path
    QWEN_MMPROJ                        projector, single-model path only
    QWEN_MMPROJ_OFFLOAD                default 1; 0 adds --no-mmproj-offload
    QWEN_IMAGE_MAX_TOKENS              --image-max-tokens where named
    QWEN_SPEC_TYPE                     draft-mtp or an ngram type; off disables
    QWEN_SPEC_DRAFT_N_MAX              1 through 16
    QWEN_SPEC_DRAFT_P_MIN              decimal fraction; 0 disables the flag
    QWEN_SPEC_BACKEND_SAMPLING         default 0
    QWEN_BACKEND_SAMPLING              default 0
    QWEN_CTX_CHECKPOINTS               default: the ledger row, else 0
    QWEN_CHECKPOINT_MIN_STEP           --checkpoint-min-step where named
    QWEN_Q4K_VARIANT                   experiment key; exported past the scrub
    QWEN_Q4K_EXPERIMENT_ARM            default 0; admits a key the row withholds
    QWEN_WEBUI_STATE_DIRECTORY         lease directory, default qwen_home_state
    QWEN_VULKAN_EXTERNAL_LEASE_PROOF   an already-held lease, verified instead

`environ` is a separate parameter because one refusal scans the whole
environment rather than one name: `env | awk '$1 ~ /^LLAMA_ARG_/'` refuses any
`LLAMA_ARG_` override, since those names are exactly what the preset sections
carry and an ambient one would reach every child.

Two sibling readers stay subprocesses at the boundary the shell calls them
from, a deferred inline port rather than a reimplementation:
`remote/read-image-mcp-server.py` is named in the doctrine as the one parser
both this policy and the image launch library read an MCP configuration with,
and `remote/image-registry.sh profile` answers from the image ledger. The
page-bound reader of `remote/stage-webui-page.sh read` is ported inline as
`read_page_bounds`, and `remote/verify-external-vulkan-lease.py` stays a
subprocess for the same reason the image readers do.
"""

from __future__ import annotations

import hashlib
import os
import re
import stat
import subprocess
from collections.abc import Mapping, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from qwen_apu.config.models import validate_cache_type, validate_q4k_variant
from qwen_apu.runtime.paths import RuntimePaths

USAGE = (
    "usage: qwen-capacity-policy.sh LLAMA_SERVER MODEL_PATH CONTEXT_SIZE "
    "[PORT [STATIC_PATH [API_KEY_FILE]]]"
)

DEFAULT_CONTEXT_CEILING = 24576
DEFAULT_CACHE_TYPE_K = "q8_0"
DEFAULT_CACHE_TYPE_V = "q4_0"
DEFAULT_FLASH_ATTENTION = "on"
DEFAULT_BATCH = 128
DEFAULT_UBATCH = 32

CACHE_TYPE_VALUES = ("f32", "f16", "bf16", "q8_0", "q5_1", "q5_0", "q4_1", "q4_0", "iq4_nl")
FLASH_ATTENTION_VALUES = ("on", "off", "auto")
SPEC_TYPE_VALUES = (
    "draft-mtp",
    "ngram-simple",
    "ngram-map-k",
    "ngram-map-k4v",
    "ngram-mod",
    "ngram-cache",
)
Q4K_VARIANT_VALUES = frozenset(
    ["-", "production/4"]
    + [
        f"{family}/{width}"
        for family in ("e4", "e4-scale", "e4-scale-licm")
        for width in ("2", "4", "8")
    ]
)

# The six draft keys carrying a set_env in the pinned common/arg.cpp, the
# layer key that breaks the SPEC pattern, and the two options with no env at
# all, which get_map_key_opt indexes by their dash-stripped argument names.
DRAFT_KEYS: tuple[str, ...] = (
    "LLAMA_ARG_SPEC_TYPE",
    "LLAMA_ARG_SPEC_DRAFT_MODEL",
    "LLAMA_ARG_SPEC_DRAFT_N_MAX",
    "LLAMA_ARG_SPEC_DRAFT_P_MIN",
    "LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_K",
    "LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_V",
    "LLAMA_ARG_N_GPU_LAYERS_DRAFT",
    "spec-draft-device",
    "spec-draft-override-tensor",
)

_PROC_DESCRIPTOR = re.compile(r"/proc/[1-9][0-9]*/fd/[0-9]+")  # appliance-path: named
_MODEL_ID = re.compile(r"[a-z0-9][a-z0-9._-]*")
_DESCRIPTOR_ALIASES = (
    re.compile(r"/proc/(?:self|thread-self|[1-9][0-9]*)/fd/[0-9]+"),  # appliance-path: named
    re.compile(
        r"/proc/(?:self|[1-9][0-9]*)/task/(?:self|[1-9][0-9]*)/fd/[0-9]+"  # appliance-path: named
    ),
    re.compile(r"/dev/fd/[0-9]+"),  # appliance-path: named
    re.compile(r"/dev/stdin"),  # appliance-path: named
)
_SECTION_HEADER = re.compile(r"^[ \t]*\[[^]]+\][ \t]*$")
_BLANK_OR_COMMENT = re.compile(r"^[ \t]*($|[#;])")
_HEX64 = re.compile(r"^[0-9a-f]{64}$")
_CANONICAL_COUNT = re.compile(r"^(0|[1-9][0-9]*)$")
_Q4K_POLICY_VALUE = re.compile(r"^(-|production/4|e4/[248]|e4-scale/[248]|e4-scale-licm/[248])$")
_WEB_SECTION_CHARACTERS = frozenset(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_,-"
)


class PolicyError(RuntimeError):
    """A refusal remote/qwen-capacity-policy.sh prints instead of an exec.

    `messages` holds the shell's lines in the order it prints them, so a
    caller reproduces its stderr verbatim; `status` holds the exit code, 2 for
    every refusal the script states itself.
    """

    def __init__(self, *messages: str, status: int = 2) -> None:
        super().__init__("\n".join(messages))
        self.messages: tuple[str, ...] = messages
        self.status = status


@dataclass(frozen=True, slots=True)
class LaunchTuple:
    """The seven per-checkpoint values the single-model path sets on the argv.

    Router mode leaves every one of them to the preset section, so a router
    plan carries this as `None`: `common_preset::merge` would otherwise push
    one value onto every served checkpoint.
    """

    context_size: int
    batch: int
    ubatch: int
    flash_attention: str
    cache_type_k: str
    cache_type_v: str
    ctx_checkpoints: int


@dataclass(frozen=True, slots=True)
class LanBounds:
    """The combined prompt and output budget, or the absence of one.

    Both bounds are set together or not at all, and their sum clamps
    `--ctx-size` downward while the output bound becomes `--n-predict`.
    """

    prompt_tokens: int | None
    output_tokens: int | None

    @property
    def named(self) -> bool:
        return self.prompt_tokens is not None

    @property
    def combined_budget(self) -> int | None:
        if self.prompt_tokens is None or self.output_tokens is None:
            return None
        return self.prompt_tokens + self.output_tokens

    def page_form(self) -> str:
        """The comparison `stage-webui-page.sh read` answers in."""
        prompt = "-" if self.prompt_tokens is None else str(self.prompt_tokens)
        output = "-" if self.output_tokens is None else str(self.output_tokens)
        return f"prompt_bound={prompt} output_bound={output}"


@dataclass(frozen=True, slots=True)
class LaunchPlan:
    """One assembled launch: what runs, under which environment, with which receipt.

    `argv` is the llama-server command with the executable first, the form
    `set -- "$llama_server" ...` builds. `exec_argv` is what the script
    actually execs: the Vulkan wrapper, the build guard and its three
    declarations, the router guard and its six authority pairs where router
    mode holds them, and `argv` whole at the end -- so the server path appears
    twice, once as the build guard's subject and once as `argv[0]`.

    `stdout_lines` and `stderr_lines` carry the receipt the launch chain reads:
    `router_q4k_policy`, `checkpoint_binding`, `q4k_binding`, and
    `vulkan_workload_lease` on stdout, `depth_validation`,
    `lan_resource_bounds`, and the two loopback-forcing notices on stderr.
    """

    argv: tuple[str, ...]
    exec_argv: tuple[str, ...]
    environment_additions: Mapping[str, str]
    environment_removals: tuple[str, ...]
    mode: str
    model_id: str | None
    model_row: ResolvedRow | None
    launch_tuple: LaunchTuple | None
    bind_host: str
    port: int
    preset_path: Path | None
    preset_section_names: tuple[str, ...]
    ctx_checkpoints: int
    q4k_variant: str
    q4k_selection_source: str
    lan_bounds: LanBounds
    checkpoint_semantics: str
    checkpoint_guard_requirement: str
    checkpoint_manifest_sha256: str
    q4k_guard_requirement: str
    stdout_lines: tuple[str, ...] = ()
    stderr_lines: tuple[str, ...] = ()


# ---------------------------------------------------------------------------
# The shell's own glob and arithmetic idioms, read positively
# ---------------------------------------------------------------------------


def _is_decimal(value: str) -> bool:
    """The shell's `*[!0-9]*` test: every character is an ASCII digit."""
    return value != "" and all(character in "0123456789" for character in value)


def _positive_decimal(value: str) -> bool:
    """`*[!0-9]* | 0` read positively: digits alone, and not the single zero.

    `00` passes this the way it passes the shell's own case, since `0` matches
    one character exactly.
    """
    return _is_decimal(value) and value != "0"


def _sha256_file(path: Path | str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


# ---------------------------------------------------------------------------
# remote/stage-webui-page.sh read, ported inline
# ---------------------------------------------------------------------------

_META_TAG = re.compile(r'^[ \t]*<meta name="([a-z0-9-]+)" content="([^"]*)">[ \t]*$')


def _read_bound(name: str, page: Path) -> str:
    text = page.read_text(encoding="utf-8", errors="replace")
    values = [
        match.group(2)
        for line in text.splitlines()
        if (match := _META_TAG.match(line)) is not None and match.group(1) == name
    ]
    mentions = sum(line.count(f'name="{name}"') for line in text.splitlines())
    if len(values) == 0:
        if mentions != 0:
            raise PolicyError(f"{page} carries a {name} tag in a form this launch never writes")
        return "-"
    if len(values) > 1 or mentions != 1:
        raise PolicyError(f"{page} carries {name} more than once")
    value = values[0]
    if not _is_decimal(value) or value.startswith("0"):
        raise PolicyError(f"{page} carries {name}={value}, which is not a positive integer")
    return value


def read_page_bounds(page: Path | str) -> str:
    """`stage-webui-page.sh read INDEX_HTML`: the two tags in comparison form."""
    path = Path(page)
    if not path.is_file():
        raise PolicyError(f"page is not a file: {path}")
    prompt = _read_bound("qwen-lan-max-prompt-tokens", path)
    output = _read_bound("qwen-lan-max-output-tokens", path)
    if (prompt == "-") != (output == "-"):
        raise PolicyError(
            f"{path} carries one LAN bound tag without the other: prompt={prompt} output={output}"
        )
    return f"prompt_bound={prompt} output_bound={output}"


# ---------------------------------------------------------------------------
# The registry view: the approved descriptor identity, or a path lookup
# ---------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class ResolvedRow:
    """The ten registry fields a single-model launch resolves its tuple from.

    These are exactly the columns the descriptor route caches through one open
    file descriptor, so a registry replaced after that read cannot change the
    row the launch serves, and exactly the columns the path route reads one at
    a time. `validated_filled_depth` and `q4k_variant` carry `-` where the row
    claims nothing, the spelling both authorities compare against.
    """

    id: str
    model_file: str
    context_ceiling: str
    cache_type_k: str
    cache_type_v: str
    flash_attention: str
    batch: str
    ubatch: str
    validated_filled_depth: str
    q4k_variant: str


def _require_canonical_positive(value: str, name: str) -> int:
    if not value.isascii() or not value.isdecimal() or value.startswith("0"):
        raise PolicyError(
            f"approved model registry row is invalid: {name} must be a canonical positive integer"
        )
    parsed = int(value)
    if parsed <= 0:
        raise PolicyError(
            f"approved model registry row is invalid: {name} must be a canonical positive integer"
        )
    return parsed


def _verify_approved_descriptor(
    model_path: str, model_id: str, device_text: str, inode_text: str, bytes_text: str
) -> None:
    """The descriptor identity check the shell runs as an inline python3 heredoc."""
    if _PROC_DESCRIPTOR.fullmatch(model_path) is None:
        raise PolicyError("approved model identity requires a canonical proc descriptor path")
    if _MODEL_ID.fullmatch(model_id) is None:
        raise PolicyError("approved model ID is malformed")
    expected: list[int] = []
    for name, value, minimum in (
        ("device", device_text, 0),
        ("inode", inode_text, 1),
        ("bytes", bytes_text, 0),
    ):
        if not value.isascii() or not value.isdecimal():
            raise PolicyError(f"approved model {name} is malformed")
        parsed = int(value)
        if parsed < minimum or str(parsed) != value:
            raise PolicyError(f"approved model {name} is malformed")
        expected.append(parsed)
    try:
        status = os.stat(model_path)
    except OSError as error:
        raise PolicyError(f"approved model descriptor cannot be stated: {error}") from None
    if not stat.S_ISREG(status.st_mode):
        raise PolicyError("approved model descriptor is not a regular file")
    observed = (status.st_dev, status.st_ino, status.st_size)
    if observed != tuple(expected):
        raise PolicyError(
            "approved model descriptor identity differs: "
            f"expected={tuple(expected)} observed={observed}"
        )


def _read_approved_registry_row(
    registry_path: Path, expected_id: str, expected_file: str
) -> dict[str, str]:
    """One registry row read through a descriptor whose identity cannot move.

    The row is read whole and the file's device, inode, size, and modification
    time are compared before and after, so a replacement during the read is
    refused rather than half-read.
    """

    def fail(message: str) -> PolicyError:
        return PolicyError(f"approved model registry row is invalid: {message}")

    try:
        with open(registry_path, "rb", buffering=0) as handle:
            before = os.fstat(handle.fileno())
            payload = handle.read()
            after = os.fstat(handle.fileno())
    except OSError as error:
        raise fail(f"registry cannot be read: {error}") from None
    if not stat.S_ISREG(before.st_mode):
        raise fail("registry is not a regular file")
    identity = ("st_dev", "st_ino", "st_size", "st_mtime_ns")
    if tuple(getattr(before, name) for name in identity) != tuple(
        getattr(after, name) for name in identity
    ):
        raise fail("registry identity changed while reading")
    try:
        text = payload.decode("utf-8")
    except UnicodeDecodeError:
        raise fail("registry is not UTF-8") from None

    matching: list[tuple[int, list[str]]] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        if not line.strip() or line.startswith("#"):
            continue
        fields = line.split("\t")
        if fields[0] != expected_id:
            continue
        if len(fields) != 23:
            raise fail(f"line {line_number} holds {len(fields)} fields instead of 23")
        matching.append((line_number, fields))
    if len(matching) != 1:
        raise fail(f"ID {expected_id} resolves to {len(matching)} rows")

    _, fields = matching[0]
    if fields[2] != expected_file:
        raise fail(f"ID {expected_id} names file {fields[2]}, publisher names {expected_file}")
    context_ceiling = _require_canonical_positive(fields[5], "context_ceiling")
    batch = _require_canonical_positive(fields[16], "batch")
    ubatch = _require_canonical_positive(fields[17], "ubatch")
    if ubatch > batch:
        raise fail(f"ubatch {ubatch} exceeds batch {batch}")
    if fields[7] not in CACHE_TYPE_VALUES:
        raise fail(f"cache_type_k is invalid: {fields[7]}")
    if fields[8] not in CACHE_TYPE_VALUES:
        raise fail(f"cache_type_v is invalid: {fields[8]}")
    if fields[9] not in FLASH_ATTENTION_VALUES:
        raise fail(f"flash_attention is invalid: {fields[9]}")
    validated_depth = fields[18]
    if validated_depth != "-":
        _require_canonical_positive(validated_depth, "validated_filled_depth")
    # The Q4_K vocabulary is stated here beside the cache and flash ones,
    # since the descriptor route exists to read one row without reopening the
    # file the registry reader would.
    if fields[22] not in Q4K_VARIANT_VALUES:
        raise fail(f"q4k_variant is invalid: {fields[22]}")
    return {
        "id": fields[0],
        "model_file": fields[2],
        "context_ceiling": str(context_ceiling),
        "cache_type_k": fields[7],
        "cache_type_v": fields[8],
        "flash_attention": fields[9],
        "batch": str(batch),
        "ubatch": str(ubatch),
        "validated_filled_depth": validated_depth,
        "q4k_variant": fields[22],
    }


def _verify_ordinary_model_path(model_path: str, model_root: str) -> None:
    """The ordinary path rule: canonical, absolute, symlink-free, inside the root."""
    collapsed = re.sub(r"/+", "/", model_path)
    normalized = os.path.normpath(collapsed)
    if any(pattern.fullmatch(normalized) for pattern in _DESCRIPTOR_ALIASES):
        raise PolicyError("descriptor-backed model path requires approved model identity")
    if not os.path.isabs(model_path) or normalized != model_path:
        raise PolicyError("ordinary model path must be canonical and absolute")
    try:
        resolved_root = Path(model_root).resolve(strict=True)
        resolved_model = Path(model_path).resolve(strict=True)
    except OSError as error:
        raise PolicyError(f"ordinary model path cannot be resolved: {error}") from None
    if str(resolved_model) != model_path:
        raise PolicyError("ordinary model path must not contain symbolic links")
    try:
        resolved_model.relative_to(resolved_root)
    except ValueError:
        raise PolicyError(f"ordinary model path escapes QWEN_MODEL_ROOT: {model_path}") from None


# ---------------------------------------------------------------------------
# Raw ledger reads: the shape the shell's AWK sees
# ---------------------------------------------------------------------------


def _raw_rows(path: Path) -> list[list[str]]:
    """Every non-comment, non-blank line split on tabs, the AWK reader's view."""
    rows: list[list[str]] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("#") or line.strip() == "":
            continue
        rows.append(line.split("\t"))
    return rows


@dataclass(frozen=True, slots=True)
class _RegistryRowView:
    """The eleven registry fields the preset validator compares a section against."""

    model_file: str
    context_default: str
    context_ceiling: str
    cache_type_k: str
    cache_type_v: str
    flash_attention: str
    tier: str
    batch: str
    ubatch: str
    validated_filled_depth: str
    q4k_variant: str


def _registry_view(
    path: Path,
) -> tuple[dict[str, _RegistryRowView], dict[str, int], dict[str, int], dict[str, str]]:
    """The registry as the tuple validator indexes it: by id, and by weights file."""
    by_id: dict[str, _RegistryRowView] = {}
    counts: dict[str, int] = {}
    id_by_file: dict[str, str] = {}
    rows_by_file: dict[str, int] = {}
    for fields in _raw_rows(path):
        padded = fields + [""] * (23 - len(fields)) if len(fields) < 23 else fields
        row_id = padded[0]
        counts[row_id] = counts.get(row_id, 0) + 1
        by_id[row_id] = _RegistryRowView(
            model_file=padded[2],
            context_default=padded[4],
            context_ceiling=padded[5],
            cache_type_k=padded[7],
            cache_type_v=padded[8],
            flash_attention=padded[9],
            tier=padded[15],
            batch=padded[16],
            ubatch=padded[17],
            validated_filled_depth=padded[18],
            q4k_variant=padded[22] if padded[22] != "" else "-",
        )
        id_by_file[padded[2]] = row_id
        rows_by_file[padded[2]] = rows_by_file.get(padded[2], 0) + 1
    return by_id, counts, rows_by_file, id_by_file


@dataclass
class _PresetSection:
    """One INI section as the validator accumulates it: counts beside values."""

    name: str
    counts: dict[str, int] = field(default_factory=dict)
    values: dict[str, str] = field(default_factory=dict)

    def record(self, key: str, value: str) -> None:
        self.counts[key] = self.counts.get(key, 0) + 1
        self.values[key] = value

    def count(self, key: str) -> int:
        return self.counts.get(key, 0)

    def value(self, key: str) -> str:
        return self.values.get(key, "")


def _parse_preset(path: Path, refusals: list[str]) -> list[_PresetSection]:
    """The INI scan both AWK validators perform, refusals recorded rather than raised."""
    sections: list[_PresetSection] = []
    current: _PresetSection | None = None
    seen: set[str] = set()
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if _BLANK_OR_COMMENT.match(line):
            continue
        if line.lstrip(" \t").startswith("["):
            if _SECTION_HEADER.match(line) is None:
                refusals.append(f"router preset carries malformed section header: {line}")
                current = None
                continue
            name = line.strip(" \t")[1:-1]
            if name != "*" and name in seen:
                refusals.append(f"router preset repeats section: {name}")
            seen.add(name)
            current = _PresetSection(name=name)
            sections.append(current)
            continue
        if current is None or current.name == "*":
            continue
        separator = line.find("=")
        if separator < 0:
            continue
        key = line[:separator].strip(" \t")
        value = line[separator + 1 :].strip(" \t")
        current.record(key, value)
    return sections


@dataclass(frozen=True, slots=True)
class PresetSectionView:
    """One router preset section, read once for every caller that needs it.

    The INI under `--models-preset` is the deployment's own claim about what it
    serves, and three callers act on it: the policy validates each section's
    tuple against the registry, the launch selects the largest resident subject
    for the memory preflight, and the gateway roster names the sections a
    picker may offer. One reader keeps those three answering from the same
    scan.
    """

    name: str
    values: Mapping[str, str]
    counts: Mapping[str, int]

    def value(self, key: str) -> str:
        return self.values.get(key, "")

    def count(self, key: str) -> int:
        return self.counts.get(key, 0)


def preset_sections(path: Path | str) -> tuple[PresetSectionView, ...]:
    """Every named section of one router preset, the `*` defaults left out.

    Refusals the scan collects are raised together, the way the shell's AWK
    reports every defective section in one run rather than the first.
    """
    refusals: list[str] = []
    sections = _parse_preset(Path(path), refusals)
    if refusals:
        raise PolicyError(*refusals)
    return tuple(
        PresetSectionView(name=entry.name, values=dict(entry.values), counts=dict(entry.counts))
        for entry in sections
        if entry.name not in ("", "*")
    )


@dataclass(frozen=True, slots=True)
class RouterSubject:
    """The preset section whose resident bytes the memory preflight is charged.

    A draft-pair section holds two checkpoints at once, since
    `common_speculative_init_result` loads the draft path as its own model
    beside the target rather than reusing the target's buffers, so the
    section's subject is the sum of both artifacts.
    """

    section: str
    model: Path
    model_bytes: int
    draft: Path | None
    draft_bytes: int

    @property
    def resident_bytes(self) -> int:
        return self.model_bytes + self.draft_bytes


def router_preflight_subject(presets: Path | str) -> RouterSubject:
    """The largest resident section of one preset, the subject qwen-launch.sh charges.

    Router presets carry their own model and projector paths, so the largest
    registry subject replaces any explicit single-model path: a preflight run
    against a smaller checkpoint reports headroom for a load that never
    happens.
    """
    path = Path(presets)
    largest: RouterSubject | None = None
    sections = preset_sections(path)
    refusals: list[str] = []
    for section in sections:
        model_count = section.count("LLAMA_ARG_MODEL")
        if model_count != 1:
            refusals.append(
                f"router preflight section {section.name} requires exactly one "
                f"LLAMA_ARG_MODEL, found {model_count}"
            )
            continue
        draft_count = section.count("LLAMA_ARG_SPEC_DRAFT_MODEL")
        if draft_count > 1:
            refusals.append(
                f"router preflight section {section.name} carries {draft_count} "
                "LLAMA_ARG_SPEC_DRAFT_MODEL keys"
            )
            continue
        model = Path(section.value("LLAMA_ARG_MODEL"))
        if not model.is_file():
            raise PolicyError(f"router preflight model is not a regular file: {model}")
        draft_text = section.value("LLAMA_ARG_SPEC_DRAFT_MODEL")
        draft = Path(draft_text) if draft_text else None
        if draft is not None and not draft.is_file():
            raise PolicyError(f"router preflight draft model is not a regular file: {draft}")
        candidate = RouterSubject(
            section=section.name,
            model=model,
            model_bytes=model.stat().st_size,
            draft=draft,
            draft_bytes=draft.stat().st_size if draft is not None else 0,
        )
        if largest is None or candidate.resident_bytes > largest.resident_bytes:
            largest = candidate
    if refusals:
        raise PolicyError(*refusals)
    if largest is None:
        raise PolicyError("router preflight carries no model section")
    return largest


# ---------------------------------------------------------------------------
# validate_router_preset_tuples
# ---------------------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class _DraftPairRow:
    """The six draft-pair fields a section is rejoined to, as ledger text."""

    target: str
    draft: str
    n_max: str
    p_min: str
    cache_k: str
    cache_v: str


def _quarantine_index(
    rows: Sequence[Sequence[str]],
) -> tuple[set[str], set[tuple[str, str, str, str, str, str, str]]]:
    """Model subjects and profile tuples, keyed the way the validator looks them up."""
    models: set[str] = set()
    profiles: set[tuple[str, str, str, str, str, str, str]] = set()
    for fields in rows:
        if not fields or fields[0] == "":
            continue
        scope = fields[1] if len(fields) > 1 else ""
        if scope == "model":
            models.add(fields[2])
        elif scope == "profile":
            profiles.add(
                (fields[2], fields[4], fields[5], fields[6], fields[7], fields[8], fields[9])
            )
    return models, profiles


def validate_router_preset_tuples(  # noqa: PLR0917
    registry_path: Path,
    presets_path: Path,
    model_root: str,
    quarantine_rows: Sequence[Sequence[str]],
    include_quarantine: str,
    web_profile_sections: str,
    web_depth_override: str,
    draft_pair_rows: Sequence[Sequence[str]],
    ctx_checkpoint_rows: Sequence[Sequence[str]],
    web_section_list: str,
    q4k_policy_rows: str,
) -> list[str]:
    """Every section's tuple, rejoined to the registry and the three ledgers.

    Returns the refusal lines rather than raising, since the shell's AWK sets
    `rejected = 1` and continues: one run names every defective section.
    """
    refusals: list[str] = []
    registry, registry_counts, rows_by_file, id_by_file = _registry_view(registry_path)
    quarantined_models, quarantined_profiles = _quarantine_index(quarantine_rows)

    pairs: dict[str, _DraftPairRow] = {}
    for fields in draft_pair_rows:
        if len(fields) < 10 or fields[3] not in ("production", "candidate"):
            continue
        pairs[fields[0]] = _DraftPairRow(
            target=fields[1],
            draft=fields[2],
            n_max=fields[4],
            p_min=fields[5],
            cache_k=fields[8],
            cache_v=fields[9],
        )
    ledger_checkpoints = {fields[0]: fields[1] for fields in ctx_checkpoint_rows if fields}
    web_sections = {name for name in web_section_list.split(",") if name}

    if q4k_policy_rows == "":
        q4k_policy_mode = "registry"
    elif q4k_policy_rows == "-":
        q4k_policy_mode = "none"
    elif q4k_policy_rows == "legacy":
        q4k_policy_mode = "legacy"
    else:
        q4k_policy_mode = "bundle"
    policy_q4k: dict[str, str] = {}
    if q4k_policy_mode == "bundle":
        for line in q4k_policy_rows.split("\n"):
            if line == "":
                continue
            fields = line.split("\t")
            policy_q4k[fields[0]] = fields[1]

    sections = _parse_preset(presets_path, refusals)
    model_sections = 0

    def reject_key(section: str, key: str, count: int) -> None:
        refusals.append(
            f"router preset section {section} requires exactly one {key}, found {count}"
        )

    def reject_value(section: str, key: str, value: str) -> None:
        refusals.append(f"router preset section {section} carries invalid {key}: {value}")

    def reject_registry_value(section: str, key: str, value: str, expected: str) -> None:
        refusals.append(
            f"router preset section {section} carries {key} {value}, registry admits {expected}"
        )

    for entry in sections:
        section = entry.name
        if section in ("", "*"):
            continue
        model_sections += 1
        section_is_web = web_profile_sections == "1" or section in web_sections

        for key in (
            "LLAMA_ARG_MODEL",
            "LLAMA_ARG_CTX_SIZE",
            "LLAMA_ARG_CACHE_TYPE_K",
            "LLAMA_ARG_CACHE_TYPE_V",
            "LLAMA_ARG_FLASH_ATTN",
            "LLAMA_ARG_BATCH",
            "LLAMA_ARG_UBATCH",
            # The checkpoint count is the seventh per-section key. The pinned
            # build defaults n_ctx_checkpoints to 32, so an absent key serves
            # thirty-two host copies of the recurrent state where the ledger
            # admits at most two.
            "LLAMA_ARG_CTX_CHECKPOINTS",
        ):
            if entry.count(key) != 1:
                reject_key(section, key, entry.count(key))

        checkpoint_value = entry.value("LLAMA_ARG_CTX_CHECKPOINTS")
        if entry.count("LLAMA_ARG_CTX_CHECKPOINTS") == 1 and not _CANONICAL_COUNT.match(
            checkpoint_value
        ):
            reject_value(section, "LLAMA_ARG_CTX_CHECKPOINTS", checkpoint_value)
        context_value = entry.value("LLAMA_ARG_CTX_SIZE")
        if entry.count("LLAMA_ARG_CTX_SIZE") == 1 and (
            not _is_decimal(context_value) or int(context_value) < 1
        ):
            reject_value(section, "LLAMA_ARG_CTX_SIZE", context_value)
        batch_value = entry.value("LLAMA_ARG_BATCH")
        if entry.count("LLAMA_ARG_BATCH") == 1 and (
            not _is_decimal(batch_value) or int(batch_value) < 1
        ):
            reject_value(section, "LLAMA_ARG_BATCH", batch_value)
        ubatch_value = entry.value("LLAMA_ARG_UBATCH")
        if entry.count("LLAMA_ARG_UBATCH") == 1 and (
            not _is_decimal(ubatch_value) or int(ubatch_value) < 1
        ):
            reject_value(section, "LLAMA_ARG_UBATCH", ubatch_value)
        if (
            entry.count("LLAMA_ARG_BATCH") == 1
            and entry.count("LLAMA_ARG_UBATCH") == 1
            and _is_decimal(batch_value)
            and _is_decimal(ubatch_value)
            and int(ubatch_value) > int(batch_value)
        ):
            reject_value(section, "LLAMA_ARG_UBATCH", ubatch_value)
        cache_k_value = entry.value("LLAMA_ARG_CACHE_TYPE_K")
        if entry.count("LLAMA_ARG_CACHE_TYPE_K") == 1 and cache_k_value not in CACHE_TYPE_VALUES:
            reject_value(section, "LLAMA_ARG_CACHE_TYPE_K", cache_k_value)
        cache_v_value = entry.value("LLAMA_ARG_CACHE_TYPE_V")
        if entry.count("LLAMA_ARG_CACHE_TYPE_V") == 1 and cache_v_value not in CACHE_TYPE_VALUES:
            reject_value(section, "LLAMA_ARG_CACHE_TYPE_V", cache_v_value)
        flash_value = entry.value("LLAMA_ARG_FLASH_ATTN")
        if entry.count("LLAMA_ARG_FLASH_ATTN") == 1 and flash_value not in FLASH_ATTENTION_VALUES:
            reject_value(section, "LLAMA_ARG_FLASH_ATTN", flash_value)

        # An MCP configuration is the execution grant, so a section outside the
        # list the head marker names carrying one would reach the network under
        # rules the launch validated as tool-free.
        mcp_count = entry.count("LLAMA_ARG_MCP_SERVERS_CONFIG")
        if web_profile_sections == "1":
            pass
        elif section in web_sections:
            if mcp_count != 1:
                reject_key(section, "LLAMA_ARG_MCP_SERVERS_CONFIG", mcp_count)
        elif mcp_count != 0:
            refusals.append(
                f"router preset section {section} carries "
                "LLAMA_ARG_MCP_SERVERS_CONFIG outside the web section list"
            )

        is_draft_pair = not section_is_web and section in pairs
        if not is_draft_pair:
            for key in DRAFT_KEYS:
                if entry.count(key) != 0:
                    refusals.append(
                        f"router preset section {section} carries {key} without a draft pair row"
                    )

        registry_key = section
        if is_draft_pair:
            pair = pairs[section]
            registry_key = pair.target

            def check_draft_key(key: str, expected: str, entry: _PresetSection = entry) -> None:
                if entry.count(key) != 1:
                    reject_key(entry.name, key, entry.count(key))
                    return
                if entry.value(key) != expected:
                    refusals.append(
                        f"router preset section {entry.name} carries {key} "
                        f"{entry.value(key)}, the draft pair ledger admits {expected}"
                    )

            draft_file = registry[pair.draft].model_file if pair.draft in registry else ""
            check_draft_key("LLAMA_ARG_SPEC_TYPE", "draft-simple")
            check_draft_key("LLAMA_ARG_SPEC_DRAFT_MODEL", f"{model_root}/{draft_file}")
            check_draft_key("LLAMA_ARG_SPEC_DRAFT_N_MAX", pair.n_max)
            check_draft_key("LLAMA_ARG_SPEC_DRAFT_P_MIN", pair.p_min)
            check_draft_key("LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_K", pair.cache_k)
            check_draft_key("LLAMA_ARG_SPEC_DRAFT_CACHE_TYPE_V", pair.cache_v)
            # Placement is stated rather than inherited:
            # common_base_params_to_speculative overwrites the draft's devices,
            # layer count, and tensor overrides with its own values, so the
            # section names them or the draft runs on automatic placement.
            check_draft_key("LLAMA_ARG_N_GPU_LAYERS_DRAFT", "all")
            check_draft_key("spec-draft-device", "Vulkan0")
            check_draft_key("spec-draft-override-tensor", ".*=Vulkan0")

        model_value = entry.value("LLAMA_ARG_MODEL")
        if section_is_web:
            prefix = f"{model_root}/"
            section_model_file = ""
            if entry.count("LLAMA_ARG_MODEL") == 1 and model_value.startswith(prefix):
                section_model_file = model_value[len(prefix) :]
                registry_key = id_by_file.get(section_model_file, "")
            else:
                registry_key = ""
            if registry_key == "":
                refusals.append(
                    f"web preset section {section} carries a LLAMA_ARG_MODEL "
                    f"outside the registry: {model_value}"
                )
                continue
            # Resolution by weights file requires the registry to name each
            # file once; two rows sharing one would pick a tier and a tuple by
            # file order, so the ambiguity is refused instead.
            if rows_by_file.get(section_model_file, 0) != 1:
                refusals.append(
                    f"web preset section {section} resolves to "
                    f"{rows_by_file.get(section_model_file, 0)} registry rows "
                    f"through model file {section_model_file}"
                )
                continue

        registry_count = registry_counts.get(registry_key, 0)
        if registry_count != 1:
            refusals.append(
                f"router preset section {section} resolves to {registry_count} registry rows"
            )
            continue
        row = registry[registry_key]

        if row.tier not in ("production", "candidate", "quarantine"):
            refusals.append(
                f"router preset section {section} has non-servable registry tier {row.tier}"
            )
        if row.tier == "quarantine" and (
            include_quarantine != "1" or registry_key not in quarantined_models
        ):
            refusals.append(
                f"router preset section {section} lacks an admitted model quarantine override"
            )

        expected_model = f"{model_root}/{row.model_file}"
        if entry.count("LLAMA_ARG_MODEL") == 1 and model_value != expected_model:
            reject_registry_value(section, "LLAMA_ARG_MODEL", model_value, expected_model)
        if entry.count("LLAMA_ARG_CTX_SIZE") == 1:
            if section_is_web:
                if _as_number(context_value) > _as_number(row.context_ceiling):
                    reject_registry_value(
                        section,
                        "LLAMA_ARG_CTX_SIZE",
                        context_value,
                        f"at most {row.context_ceiling}",
                    )
                # A preset persists across a registry edit, so the depth the
                # generator validated is rechecked here. `-` is refused by its
                # literal spelling, since it reads as 0 in a numeric comparison
                # and would name a nonsense expectation.
                if web_depth_override != "1":
                    if row.validated_filled_depth == "-":
                        refusals.append(
                            f"web preset section {section} serves context {context_value} "
                            f"where the registry records no filled depth for {registry_key}"
                        )
                    elif _as_number(context_value) > _as_number(row.validated_filled_depth):
                        reject_registry_value(
                            section,
                            "LLAMA_ARG_CTX_SIZE",
                            context_value,
                            f"at most validated_filled_depth {row.validated_filled_depth}",
                        )
            elif context_value != row.context_default:
                reject_registry_value(
                    section, "LLAMA_ARG_CTX_SIZE", context_value, row.context_default
                )
        if entry.count("LLAMA_ARG_CACHE_TYPE_K") == 1 and cache_k_value != row.cache_type_k:
            reject_registry_value(
                section, "LLAMA_ARG_CACHE_TYPE_K", cache_k_value, row.cache_type_k
            )
        if entry.count("LLAMA_ARG_CACHE_TYPE_V") == 1 and cache_v_value != row.cache_type_v:
            reject_registry_value(
                section, "LLAMA_ARG_CACHE_TYPE_V", cache_v_value, row.cache_type_v
            )
        if entry.count("LLAMA_ARG_FLASH_ATTN") == 1 and flash_value != row.flash_attention:
            reject_registry_value(section, "LLAMA_ARG_FLASH_ATTN", flash_value, row.flash_attention)
        if entry.count("LLAMA_ARG_BATCH") == 1 and batch_value != row.batch:
            reject_registry_value(section, "LLAMA_ARG_BATCH", batch_value, row.batch)
        if entry.count("LLAMA_ARG_UBATCH") == 1 and ubatch_value != row.ubatch:
            reject_registry_value(section, "LLAMA_ARG_UBATCH", ubatch_value, row.ubatch)

        # The count is compared against the ledger row of the registry key the
        # section resolved to; a row outside the ledger admits 0.
        expected_checkpoints = ledger_checkpoints.get(registry_key, "0")
        if (
            entry.count("LLAMA_ARG_CTX_CHECKPOINTS") == 1
            and _CANONICAL_COUNT.match(checkpoint_value)
            and checkpoint_value != expected_checkpoints
        ):
            refusals.append(
                f"router preset section {section} carries LLAMA_ARG_CTX_CHECKPOINTS "
                f"{checkpoint_value}, the context checkpoint ledger admits {expected_checkpoints}"
            )

        # The Q4_K formulation is a per-row release, so the key is present
        # exactly where the row names one; an absent key serves the production
        # module every build executes unkeyed.
        q4k_count = entry.count("LLAMA_ARG_VK_Q4K_VARIANT")
        q4k_value = entry.value("LLAMA_ARG_VK_Q4K_VARIANT")
        if q4k_policy_mode == "registry":
            expected_q4k = row.q4k_variant if row.q4k_variant != "" else "-"
        elif q4k_policy_mode in ("none", "legacy"):
            expected_q4k = "-"
        elif registry_key in policy_q4k:
            expected_q4k = policy_q4k[registry_key]
        else:
            refusals.append(
                f"router preset section {section} serves {registry_key}, "
                "which the bundled Q4_K policy never names"
            )
            expected_q4k = ""
        if expected_q4k == "":
            # The bundled policy already refused this section; a second reason
            # for one defect would read as two.
            pass
        elif expected_q4k == "-":
            if q4k_count != 0 and q4k_policy_mode == "legacy":
                refusals.append(
                    f"router preset section {section} carries LLAMA_ARG_VK_Q4K_VARIANT "
                    f"{q4k_value} where the bundle records no Q4_K formulation policy; "
                    "re-assemble the bundle with build-deployment-bundle.sh, or name the "
                    "policy it was generated against in QWEN_BUNDLE_Q4K_POLICY"
                )
            elif q4k_count != 0:
                authority = (
                    "the registry row"
                    if q4k_policy_mode == "registry"
                    else "the bundled Q4_K policy"
                )
                refusals.append(
                    f"router preset section {section} carries LLAMA_ARG_VK_Q4K_VARIANT "
                    f"{q4k_value}, {authority} releases no Q4_K formulation for that row"
                )
        elif q4k_count != 1:
            reject_key(section, "LLAMA_ARG_VK_Q4K_VARIANT", q4k_count)
        elif q4k_value != expected_q4k:
            reject_registry_value(section, "LLAMA_ARG_VK_Q4K_VARIANT", q4k_value, expected_q4k)

        if include_quarantine != "1" and registry_key in quarantined_models:
            refusals.append(f"router preset section {section} is excluded by model quarantine")

        profile_key = (
            registry_key,
            context_value,
            batch_value,
            ubatch_value,
            cache_k_value,
            cache_v_value,
            flash_value,
        )
        quarantined_section = (
            registry_key in quarantined_models
            or profile_key in quarantined_profiles
            or row.tier == "quarantine"
        )
        tags_count = entry.count("LLAMA_ARG_TAGS")
        tags_value = entry.value("LLAMA_ARG_TAGS")
        if include_quarantine == "1" and quarantined_section:
            if tags_count != 1:
                reject_key(section, "LLAMA_ARG_TAGS", tags_count)
            else:
                tags = tags_value.split(",")
                quarantine_tag = "quarantine" in tags
                default_tag = "default" in tags
                conflicting = any(
                    tag in ("production", "candidate", "archive", "rejected") for tag in tags
                )
                if not quarantine_tag or default_tag or conflicting:
                    refusals.append(
                        f"router preset section {section} carries unsafe quarantine "
                        f"tags: {tags_value}"
                    )
        if include_quarantine != "1" and profile_key in quarantined_profiles:
            refusals.append(f"router preset section {section} is excluded by profile quarantine")

    if model_sections == 0:
        refusals.append("router preset carries no model section")
    return refusals


def _as_number(value: str) -> int:
    """AWK's `value + 0`: the leading decimal run, or zero."""
    match = re.match(r"^[0-9]+", value)
    return int(match.group(0)) if match else 0


# ---------------------------------------------------------------------------
# The shell readers this policy consumes, ported at the shape their AWK reads
# ---------------------------------------------------------------------------

_REGISTRY_FIELD_NAMES: tuple[str, ...] = (
    "id",
    "role",
    "model_file",
    "fetch_script",
    "context_default",
    "context_ceiling",
    "context_target",
    "cache_type_k",
    "cache_type_v",
    "flash_attention",
    "projector",
    "projector_fetch_script",
    "decode_tok_s",
    "prefill_tok_s",
    "quality",
    "tier",
    "batch",
    "ubatch",
    "validated_filled_depth",
    "validation_evidence",
    "raw_tool_selection",
    "guarded_tool_execution",
    "q4k_variant",
)


def registry_field(registry_path: Path, kind: str, selector: str, name: str) -> str | None:
    """`model-registry.sh id|path SELECTOR FIELD`, at that reader's own tolerance.

    The selector path of remote/model-registry.sh skips a `#` line and a row
    holding fewer than 23 fields and answers from the first row that matches,
    so it reads a ledger with no header comment and applies neither the closed
    `q4k_variant` vocabulary nor the tier check `emit_servable_rows` applies.
    `qwen_apu.config.models.model_by_path` validates the whole ledger instead
    and refuses a headerless one, which is the stricter contract that module
    commits to; this policy reproduces the selector's tolerance, because its
    own fallbacks are defined against a registry miss rather than a refusal.
    """
    if not os.access(registry_path, os.R_OK):
        return None
    for line in registry_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) < 23:
            continue
        if kind == "id" and fields[0] != selector:
            continue
        if kind == "path" and not (
            len(fields[2]) <= len(selector) and selector.endswith(fields[2])
        ):
            continue
        index = _REGISTRY_FIELD_NAMES.index(name)
        return fields[index]
    return None


def _repository_relative(value: str) -> bool:
    """The shell's `'' | .. | /* | ../* | */../* | */..` case, read positively."""
    if value in ("", "..") or value.startswith(("/", "../")):
        return False
    return not (value.endswith("/..") or "/../" in value)


def quarantine_rows(quarantine_path: Path, query: str, runtime_mode: str = "") -> list[list[str]]:
    """`model-registry.sh quarantine-subjects|quarantine-profiles|quarantine-rows`.

    Every row is validated and an invalid one is skipped; one invalid row
    anywhere makes the whole query refuse, which is what stops a launch from
    reading a quarantine authority it cannot trust.
    """
    if not os.access(quarantine_path, os.R_OK):
        raise PolicyError(f"quarantine registry is unreadable: {quarantine_path}", status=1)
    invalid: list[str] = []
    answers: list[list[str]] = []
    for number, line in enumerate(
        quarantine_path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1
    ):
        if line.startswith("#") or line.strip() == "":
            continue
        fields = line.split("\t")
        row_invalid = False
        if len(fields) != 14:
            invalid.append(f"quarantine row {number} holds {len(fields)} fields, expected 14")
            continue
        if fields[0] == "" or fields[2] == "":
            invalid.append(f"quarantine row {number} requires non-empty id and subject")
            row_invalid = True
        if fields[1] not in ("model", "profile"):
            invalid.append(f"quarantine row {number} carries invalid scope {fields[1]}")
            row_invalid = True
        if fields[13] not in ("any", "router-child", "standalone"):
            invalid.append(f"quarantine row {number} carries invalid runtime mode {fields[13]}")
            row_invalid = True
        if fields[1] == "model":
            for index in range(4, 10):
                if fields[index] != "-":
                    invalid.append(
                        f"model quarantine row {number} carries tuple field "
                        f"{index + 1}: {fields[index]}"
                    )
                    row_invalid = True
        if fields[1] == "profile":
            geometry = fields[4:7]
            if not all(re.fullmatch(r"[1-9][0-9]*", value) for value in geometry):
                invalid.append(f"profile quarantine row {number} carries invalid depth or geometry")
                row_invalid = True
            elif int(fields[6]) > int(fields[5]):
                invalid.append(f"profile quarantine row {number} carries ubatch above batch")
                row_invalid = True
            if fields[7] not in CACHE_TYPE_VALUES or fields[8] not in CACHE_TYPE_VALUES:
                invalid.append(f"profile quarantine row {number} carries invalid cache type")
                row_invalid = True
            if fields[9] not in FLASH_ATTENTION_VALUES:
                invalid.append(f"profile quarantine row {number} carries invalid flash attention")
                row_invalid = True
        if row_invalid:
            continue
        if runtime_mode != "" and fields[13] not in ("any", runtime_mode):
            continue
        if query == "quarantine-subjects" and fields[1] == "model":
            answers.append([fields[2]])
        elif query == "quarantine-profiles" and fields[1] == "profile":
            answers.append([fields[2], *fields[4:10]])
        elif query == "quarantine-rows":
            answers.append(fields)
    if invalid:
        raise PolicyError(*invalid, status=1)
    return answers


def ctx_checkpoint_rows(ledger_path: Path, registry_path: Path) -> list[list[str]]:
    """`model-registry.sh ctx-checkpoints`: the whole ledger, validated before it answers."""
    if not os.access(ledger_path, os.R_OK):
        raise PolicyError(f"context checkpoint ledger is unreadable: {ledger_path}", status=1)
    if not os.access(registry_path, os.R_OK):
        raise PolicyError(f"model registry is unreadable: {registry_path}", status=1)
    known = {fields[0] for fields in _raw_rows(registry_path) if fields}
    bad: list[str] = []
    seen: set[str] = set()
    rows: list[list[str]] = []
    for number, line in enumerate(
        ledger_path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1
    ):
        if line.startswith("#") or line.strip() == "":
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            bad.append(f"context checkpoint row {number} holds {len(fields)} fields, expected 3")
            continue
        model_id, count, evidence = fields
        if model_id == "":
            bad.append(f"context checkpoint row {number} carries an empty model_id")
        if model_id in seen:
            bad.append(f"duplicate model_id {model_id} at context checkpoint row {number}")
        seen.add(model_id)
        if model_id not in known:
            bad.append(f"{model_id}: model_id is absent from the model registry")
        if not _CANONICAL_COUNT.match(count):
            bad.append(
                f"{model_id}: ctx_checkpoints {count} is not a canonical non-negative integer"
            )
        if evidence == "":
            bad.append(f"{model_id}: evidence is empty; write - for an unmeasured zero")
        elif evidence == "-" and count != "0":
            bad.append(f"{model_id}: a count above 0 requires retained evidence")
        rows.append(fields)
    if bad:
        raise PolicyError(*bad, status=1)
    # The AWK pass runs to completion before the shell loop tests each retained
    # evidence path, so a ledger carrying both defect classes reports the
    # field-shape messages alone.
    paths = [
        f"{row[0]}: evidence is not a repository-relative path: {row[2]}"
        for row in rows
        if row[2] != "-" and not _repository_relative(row[2])
    ]
    if paths:
        raise PolicyError(*paths, status=1)
    return rows


def draft_pair_rows(
    pairs_path: Path, registry_path: Path, quarantine_path: Path
) -> list[list[str]]:
    """`model-registry.sh draft-pairs`: the whole ledger, rejoined to two authorities."""
    if not os.access(pairs_path, os.R_OK):
        raise PolicyError(f"draft pair ledger is unreadable: {pairs_path}", status=1)
    if not os.access(registry_path, os.R_OK):
        raise PolicyError(f"model registry is unreadable: {registry_path}", status=1)
    quarantined = {row[0] for row in quarantine_rows(quarantine_path, "quarantine-subjects")}
    known: dict[str, str] = {}
    for fields in _raw_rows(registry_path):
        if len(fields) >= 5:
            known[fields[0]] = fields[4]
    bad: list[str] = []
    seen: set[str] = set()
    rows: list[list[str]] = []
    for number, line in enumerate(
        pairs_path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1
    ):
        if line.startswith("#") or line.strip() == "":
            continue
        fields = line.split("\t")
        if len(fields) != 12:
            bad.append(f"draft pair row {number} holds {len(fields)} fields, expected 12")
            continue
        pair_id = fields[0]
        if pair_id == "":
            bad.append(f"draft pair row {number} carries an empty pair_id")
            continue
        if pair_id in seen:
            bad.append(f"duplicate pair_id {pair_id} at row {number}")
        seen.add(pair_id)
        target, draft, tier = fields[1], fields[2], fields[3]
        if target not in known:
            bad.append(f"{pair_id}: target_model_id {target} is absent from the model registry")
        if draft not in known:
            bad.append(f"{pair_id}: draft_model_id {draft} is absent from the model registry")
        # A checkpoint drafting itself loads one artifact twice for a draft
        # that agrees with the target by construction.
        if target == draft:
            bad.append(f"{pair_id}: target and draft name the same checkpoint {target}")
        if target in quarantined:
            bad.append(f"{pair_id}: target {target} is excluded by model quarantine")
        if draft in quarantined:
            bad.append(f"{pair_id}: draft {draft} is excluded by model quarantine")
        if tier not in ("production", "candidate", "quarantine", "archive", "rejected"):
            bad.append(f"{pair_id}: tier {tier} is outside the vocabulary")
        n_max = fields[4]
        if not re.fullmatch(r"[1-9][0-9]*", n_max):
            bad.append(f"{pair_id}: spec_draft_n_max {n_max} is not a canonical positive integer")
        elif int(n_max) > 16:
            bad.append(f"{pair_id}: spec_draft_n_max {n_max} exceeds the operational maximum of 16")
        for name, value in (("spec_draft_p_min", fields[5]), ("acceptance_floor", fields[6])):
            if not re.fullmatch(r"(0|1)(\.[0-9]+)?", value) or float(value) > 1:
                bad.append(f"{pair_id}: {name} {value} is not a decimal fraction in [0,1]")
        draft_context = fields[7]
        if not re.fullmatch(r"[1-9][0-9]*", draft_context):
            bad.append(
                f"{pair_id}: draft_context {draft_context} is not a canonical positive integer"
            )
        elif target in known and draft_context != known[target]:
            bad.append(
                f"{pair_id}: draft_context {draft_context} differs from target "
                f"context_default {known[target]}"
            )
        if fields[8] not in CACHE_TYPE_VALUES:
            bad.append(
                f"{pair_id}: draft_cache_type_k {fields[8]} is outside the runtime vocabulary"
            )
        if fields[9] not in CACHE_TYPE_VALUES:
            bad.append(
                f"{pair_id}: draft_cache_type_v {fields[9]} is outside the runtime vocabulary"
            )
        evidence = fields[10]
        if evidence == "":
            bad.append(f"{pair_id}: validated_evidence is empty; write - for an unmeasured pairing")
        elif tier == "production" and evidence == "-":
            bad.append(f"{pair_id}: production pairing requires retained validated_evidence")
        # The note is the alias display name, and common/arg.cpp splits that
        # value on commas into a set of routing names.
        notes = fields[11]
        if notes == "" or "," in notes or notes[:1].isspace() or notes[-1:].isspace():
            bad.append(
                f"{pair_id}: notes is the alias display name and holds no comma "
                f"or edge whitespace: {notes}"
            )
        rows.append(fields)
    if bad:
        raise PolicyError(*bad, status=1)
    # The AWK pass runs to completion first here too, so the evidence-path test
    # reports only over a ledger whose row shapes all passed.
    paths = [
        f"{row[0]}: validated evidence is not a repository-relative path: {row[10]}"
        for row in rows
        if row[10] != "-" and not _repository_relative(row[10])
    ]
    if paths:
        raise PolicyError(*paths, status=1)
    return rows


# ---------------------------------------------------------------------------
# validate_web_preset_execution_policies and the image lane
# ---------------------------------------------------------------------------


def validate_web_preset_execution_policies(  # noqa: PLR0917
    ledger_path: Path,
    presets_path: Path,
    authorizer_ready: str,
    web_all_sections: str,
    web_section_list: str,
) -> list[str]:
    """Rejoin each web section to the ledger row whose execution grant it claims.

    A row moved to `refused`, or removed outright, leaves a persisted section
    launching an MCP configuration the ledger no longer authorizes, so the
    rejoin requires the row to exist, to carry an emitting policy, and to
    carry the policy the section's own tags claim.
    """
    refusals: list[str] = []
    policies: dict[str, str] = {}
    for fields in _raw_rows(ledger_path):
        if len(fields) >= 12:
            policies[fields[0]] = fields[11]
    web_sections = {name for name in web_section_list.split(",") if name}
    for entry in _parse_preset(presets_path, []):
        section = entry.name
        if section in ("", "*"):
            continue
        if not (web_all_sections == "1" or section in web_sections):
            continue
        tags_value = entry.value("LLAMA_ARG_TAGS")
        has_mcp = entry.count("LLAMA_ARG_MCP_SERVERS_CONFIG") > 0
        # A review-only section names a vision checkpoint rather than a web
        # profile, so the ledger holds no row for it and what makes it safe is
        # that it holds no grant at all.
        if re.search(r"(^|,)review-only(,|$)", tags_value):
            if has_mcp:
                refusals.append(
                    f"web preset section {section} is review-only and carries "
                    "LLAMA_ARG_MCP_SERVERS_CONFIG"
                )
            continue
        if section not in policies:
            refusals.append(
                f"web preset section {section} names a profile the ledger "
                f"{ledger_path} no longer carries"
            )
            continue
        ledger_policy = policies[section]
        if ledger_policy not in ("validator-gated", "ui-mediated"):
            refusals.append(
                f"web preset section {section} carries ledger execution_policy "
                f"{ledger_policy}, which emits no section"
            )
            continue
        if ledger_policy == "validator-gated" and authorizer_ready != "1":
            refusals.append(f"web preset section {section} requires QWEN_WEB_AUTHORIZER_READY=1")
        section_policy = ""
        for tag in tags_value.split(","):
            if tag in ("validator-gated", "ui-mediated", "refused"):
                section_policy = tag
                break
        if section_policy != ledger_policy:
            refusals.append(
                f"web preset section {section} claims execution_policy "
                f"{section_policy} where the ledger carries {ledger_policy}"
            )
    return refusals


def section_mcp_configurations(presets_path: Path) -> list[tuple[str, str]]:
    """Every `LLAMA_ARG_MCP_SERVERS_CONFIG` beside the section that carries it."""
    configurations: list[tuple[str, str]] = []
    section = ""
    for line in presets_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if _BLANK_OR_COMMENT.match(line):
            continue
        if line.lstrip(" \t").startswith("["):
            section = line.strip(" \t").lstrip("[").rstrip("]")
            continue
        if section == "":
            continue
        separator = line.find("=")
        if separator < 0:
            continue
        key = line[:separator].strip(" \t")
        if key == "LLAMA_ARG_MCP_SERVERS_CONFIG":
            configurations.append((section, line[separator + 1 :].strip(" \t")))
    return configurations


def validate_image_preset_lane(
    script_directory: Path,
    presets_path: Path,
    image_profile: str,
    image_profiles_path: str,
    image_profiles_sha256: str,
) -> list[str]:
    """The image lane's two-directional rejoin between the preset and the ledger.

    A preset naming an image profile requires every section's MCP
    configuration to carry an image server bound to that profile and to its
    own section as the language profile; a preset naming none requires every
    configuration to carry no image server at all, which is what a preset
    generated before the lane says.
    """
    refusals: list[str] = []
    for section, configuration in section_mcp_configurations(presets_path):
        if section == "":
            continue
        reader = script_directory / "read-image-mcp-server.py"
        completed = subprocess.run(
            [str(reader), configuration], capture_output=True, text=True, check=False
        )
        if completed.returncode != 0:
            refusals.append(
                f"router preset section {section} names an MCP configuration "
                f"this policy cannot read: {configuration}"
            )
            continue
        report = dict(line.split("=", 1) for line in completed.stdout.splitlines() if "=" in line)
        state = report.get("image_server", "")
        if image_profile == "":
            if state == "present":
                refusals.append(
                    f"router preset section {section} carries an image server "
                    "where the preset names no image profile"
                )
                refusals.append("regenerate the preset tree with remote/build-router-presets.sh")
            continue
        if state != "present":
            refusals.append(
                f"router preset names image profile {image_profile} and section "
                f"{section} carries no image server"
            )
            continue
        if report.get("QWEN_IMAGE_PROFILE", "") != image_profile:
            refusals.append(
                f"router preset section {section} arms image profile "
                f"{report.get('QWEN_IMAGE_PROFILE', '')} where the preset names {image_profile}"
            )
        if report.get("QWEN_IMAGE_LANGUAGE_PROFILE", "") != section:
            refusals.append(
                f"router preset section {section} carries an image server bound to "
                f"language profile {report.get('QWEN_IMAGE_LANGUAGE_PROFILE', '')}"
            )
            refusals.append(
                "the grant binds the language profile and the image profile "
                "together, so the section signs for itself"
            )
    if refusals:
        return refusals
    if image_profile == "":
        return []
    # A preset persists across an edit to the image ledger, so the row it names
    # is read again here and the digest binds every row rather than that field.
    ledger = Path(image_profiles_path)
    if not ledger.is_file():
        return [f"image profile ledger identity cannot be measured: {image_profiles_path}"]
    measured = _sha256_file(ledger)
    if measured != image_profiles_sha256:
        return [
            f"image profile ledger identity changed: expected "
            f"{image_profiles_sha256}, measured {measured}"
        ]
    completed = subprocess.run(
        [str(script_directory / "image-registry.sh"), "profile", image_profile],
        capture_output=True,
        text=True,
        check=False,
        env={**os.environ, "QWEN_IMAGE_PROFILES": image_profiles_path},
    )
    if completed.returncode != 0:
        return [
            f"the preset names image profile {image_profile}, which "
            f"{image_profiles_path} holds no row for"
        ]
    policy = ""
    for line in completed.stdout.splitlines():
        if line.startswith("execution_policy="):
            policy = line[len("execution_policy=") :]
    if policy != "validator-gated":
        return [
            f"image profile {image_profile} carries execution_policy "
            f"{policy or '<absent>'}, and only validator-gated reaches a runtime"
        ]
    return []


def _q4k_policy(policy_path: str) -> tuple[str, str]:
    """The bundled Q4_K formulation policy as rows and the identity that names it.

    An empty value reads the registry column, `-` releases nothing on every
    row, `legacy` is what a bundle assembled before the column records, and a
    path carries `model_id<TAB>q4k_variant` rows the preset was generated
    against.
    """
    if policy_path in ("", "registry"):
        return "", "registry"
    if policy_path == "-":
        return "-", "none"
    if policy_path == "legacy":
        return "legacy", "legacy"
    path = Path(policy_path)
    if not path.is_file() or not os.access(path, os.R_OK):
        raise PolicyError(f"the bundled Q4_K formulation policy is unreadable: {policy_path}")
    rows: list[str] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if re.match(r"^[ \t]*($|#)", line):
            continue
        fields = line.split("\t")
        if len(fields) != 2 or fields[0] == "" or not _Q4K_POLICY_VALUE.match(fields[1]):
            raise PolicyError(
                f"the bundled Q4_K formulation policy carries a malformed row: {line}"
            )
        rows.append(f"{fields[0]}\t{fields[1]}")
    if not rows:
        raise PolicyError(f"the bundled Q4_K formulation policy carries no rows: {policy_path}")
    return "\n".join(rows), _sha256_file(path)


def _marker(presets_path: Path, prefix: str) -> str:
    """One `# name=value` head marker, the way `sed -n 's/^# name=//p'` reads it."""
    values = [
        line[len(prefix) :]
        for line in presets_path.read_text(encoding="utf-8", errors="replace").splitlines()
        if line.startswith(prefix)
    ]
    return "\n".join(values)


def _measure_authority(name: str, path: Path | str) -> str:
    try:
        return _sha256_file(path)
    except OSError:
        raise PolicyError(f"{name} identity cannot be measured: {path}") from None


@dataclass(frozen=True, slots=True)
class _RouterState:
    """Everything the router path resolves once and reads twice.

    The authorities are validated before the argv is assembled and again
    immediately before the exec, so a registry, quarantine ledger, draft-pair
    ledger, web ledger, or checkpoint ledger replaced in between invalidates
    the assembled command rather than reaching llama-server.
    """

    presets: Path
    registry: Path
    quarantine_registry: Path
    draft_pair_registry: Path
    ctx_checkpoint_ledger: Path
    model_root: str
    web_presets_whole_file: str
    web_sections: str
    web_mode: bool
    web_profiles: Path
    web_profiles_guard_path: str
    web_profiles_guard_sha256: str
    web_authorizer_ready: str
    web_depth_override: str
    quarantine_override: str
    image_profile: str
    image_profiles: str
    image_profiles_sha256: str
    q4k_policy_rows: str
    q4k_policy_identity: str
    draft_pair_guard_path: str


def _validate_current_router_authorities(script_directory: Path, state: _RouterState) -> list[str]:
    """Read every mutable authority and rejoin the preset to the rows it holds now."""
    try:
        quarantine = quarantine_rows(state.quarantine_registry, "quarantine-rows", "router-child")
    except PolicyError as error:
        raise PolicyError(*error.messages, "router quarantine authority is unavailable") from None
    pairs: list[list[str]] = []
    if state.web_presets_whole_file != "1":
        # A web preset names profiles rather than pair ids and emits no draft
        # key, so that shape resolves against an empty ledger and joins nothing.
        try:
            pairs = draft_pair_rows(
                state.draft_pair_registry, state.registry, state.quarantine_registry
            )
        except PolicyError as error:
            raise PolicyError(
                *error.messages, "router draft pair authority is unavailable"
            ) from None
    try:
        checkpoints = ctx_checkpoint_rows(state.ctx_checkpoint_ledger, state.registry)
    except PolicyError as error:
        raise PolicyError(
            *error.messages, "router context checkpoint authority is unavailable"
        ) from None

    refusals = validate_router_preset_tuples(
        state.registry,
        state.presets,
        state.model_root,
        quarantine,
        state.quarantine_override,
        state.web_presets_whole_file,
        state.web_depth_override,
        pairs,
        checkpoints,
        state.web_sections,
        state.q4k_policy_rows,
    )
    if refusals:
        raise PolicyError(
            *refusals,
            f"router presets do not carry complete admitted tuples: {state.presets}",
        )
    # Which authority answered for the formulation is part of what this launch
    # serves, so the receipt reads it rather than inferring it from the preset.
    source = {"": "registry", "-": "unreleased", "legacy": "unrecorded"}.get(
        state.q4k_policy_rows, "bundle"
    )
    stdout = [f"router_q4k_policy source={source} identity={state.q4k_policy_identity}"]

    if state.web_mode:
        measured = _measure_authority("web profile ledger", state.web_profiles)
        if measured != state.web_profiles_guard_sha256:
            raise PolicyError(
                f"web profile ledger identity changed: expected "
                f"{state.web_profiles_guard_sha256}, measured {measured}"
            )
        if not os.access(state.web_profiles, os.R_OK):
            raise PolicyError(f"web profile ledger is unreadable: {state.web_profiles}")
        web_refusals = validate_web_preset_execution_policies(
            state.web_profiles,
            state.presets,
            state.web_authorizer_ready,
            state.web_presets_whole_file,
            state.web_sections,
        )
        if web_refusals:
            raise PolicyError(
                *web_refusals,
                f"web preset sections lost their ledger execution grant: {state.presets}",
                "regenerate the preset tree with remote/build-web-presets.sh",
            )
    lane = validate_image_preset_lane(
        script_directory,
        state.presets,
        state.image_profile,
        state.image_profiles,
        state.image_profiles_sha256,
    )
    if lane:
        raise PolicyError(
            *lane, f"the router preset image lane fails its own markers: {state.presets}"
        )
    return stdout


def build_launch_plan(  # noqa: C901, PLR0917
    llama_server: Path | str,
    model_path: Path | str,
    context_size: str | int,
    server_port: str | int = "8080",
    static_path: str = "",
    api_key_file: str = "",
    *,
    ui: bool = False,
    script_directory: Path | None = None,
    environ: Mapping[str, str] | None = None,
    qwen_router: str = "0",
    qwen_bind_host: str = "127.0.0.1",
    qwen_cors_origins: str = "localhost",
    qwen_web_lan: str = "0",
    qwen_web_lan_open: str = "0",
    qwen_approved_model_id: str = "",
    qwen_approved_model_file: str = "",
    qwen_approved_model_device: str = "",
    qwen_approved_model_inode: str = "",
    qwen_approved_model_bytes: str = "",
    qwen_model_registry: str = "",
    qwen_model_root: str = "",
    qwen_quarantine_registry: str = "",
    qwen_draft_pairs: str = "",
    qwen_ctx_checkpoint_ledger: str = "",
    qwen_lan_max_prompt_tokens: str = "",
    qwen_lan_max_output_tokens: str = "",
    qwen_cache_type_k: str = "",
    qwen_cache_type_v: str = "",
    qwen_flash_attn: str = "",
    qwen_cache_override_context_ceiling: str = "",
    qwen_batch_size: str = "",
    qwen_ubatch_size: str = "",
    qwen_router_presets: str = "",
    qwen_router_preset_sha256: str = "",
    qwen_router_max: str = "1",
    qwen_router_include_quarantine: str = "0",
    qwen_web_profiles: str = "",
    qwen_web_authorizer_ready: str = "0",
    qwen_bundle_q4k_policy: str = "",
    qwen_mmproj: str = "",
    qwen_mmproj_offload: str = "1",
    qwen_image_max_tokens: str = "",
    qwen_spec_type: str = "",
    qwen_spec_draft_n_max: str = "",
    qwen_spec_draft_p_min: str = "",
    qwen_spec_backend_sampling: str = "0",
    qwen_backend_sampling: str = "0",
    qwen_ctx_checkpoints: str = "",
    qwen_checkpoint_min_step: str = "",
    qwen_q4k_variant: str = "",
    qwen_q4k_experiment_arm: str = "0",
    qwen_webui_state_directory: str = "",
    qwen_vulkan_external_lease_proof: str = "",
) -> LaunchPlan:
    """The launch remote/qwen-capacity-policy.sh assembles, checked in its own order."""
    if script_directory is None:
        script_directory = RuntimePaths.resolve().tree / "remote"
    directory = Path(script_directory).resolve()
    paths = RuntimePaths.resolve(directory.parent)
    ambient = dict(environ) if environ is not None else {}
    stdout_lines: list[str] = []
    stderr_lines: list[str] = []

    router_enabled = qwen_router == "1"
    if qwen_router not in ("0", "1"):
        raise PolicyError(f"QWEN_ROUTER must be 0 or 1: {qwen_router}")
    bind_host = qwen_bind_host

    if bind_host not in ("127.0.0.1", "localhost", "0.0.0.0"):  # noqa: S104
        if bind_host == "" or any(character not in "0123456789." for character in bind_host):
            raise PolicyError(
                f"bind host must be 127.0.0.1, localhost, 0.0.0.0, or an IPv4 address: {bind_host}"
            )

    # The API key is optional at every bind address on the ordinary serving
    # path: it authenticates callers and grants no capability the model itself
    # withholds, so a trusted network serves without one.
    if api_key_file and not static_path:
        raise PolicyError("an API key file requires a static path")

    # The web and image lanes are the exception. The open lane refuses a key
    # file and the bearer lane refuses its absence, so the argv carries the
    # credential state the launch announced.
    if qwen_web_lan == "1":
        if qwen_web_lan_open == "1" and api_key_file:
            raise PolicyError(
                "the open LAN exposure serves without a bearer, and an API key file "
                f"reaches this launch: {api_key_file}",
                "QWEN_WEB_LAN_OPEN=1 exports QWEN_REQUIRE_API_KEY=0; a launch reaching "
                f"here with a key binds {bind_host} authenticated where the launch "
                "announced an open listener",
            )
        if qwen_web_lan_open == "0" and not api_key_file:
            raise PolicyError(
                "the LAN exposure serves an authenticated listener, and no API key "
                "file reaches this launch",
                "the web and image launchers export QWEN_REQUIRE_API_KEY=1; a launch "
                f"reaching here without one binds {bind_host} unauthenticated",
            )

    server = str(llama_server)
    model = str(model_path)
    if not os.access(server, os.X_OK):
        raise PolicyError(f"llama-server is not executable: {server}")
    if not Path(model).is_file():
        raise PolicyError(f"model is not a regular file: {model}")

    registry_path = Path(qwen_model_registry) if qwen_model_registry else directory / "models.tsv"
    model_root = qwen_model_root if qwen_model_root else str(paths["qwen_home_models"])

    # A served measurement launches a descriptor path so pathname replacement
    # cannot change the bytes llama-server opens, and the policy re-stats that
    # descriptor before the registry ID becomes policy authority.
    approved = (
        qwen_approved_model_id,
        qwen_approved_model_file,
        qwen_approved_model_device,
        qwen_approved_model_inode,
        qwen_approved_model_bytes,
    )
    approved_count = sum(1 for value in approved if value)
    approved_fields: Mapping[str, str] | None = None
    if approved_count != 0:
        if approved_count != 5:
            raise PolicyError("approved model identity requires ID, file, device, inode, and bytes")
        if router_enabled:
            raise PolicyError("approved single-model identity is refused in router mode")
        _verify_approved_descriptor(
            model,
            qwen_approved_model_id,
            qwen_approved_model_device,
            qwen_approved_model_inode,
            qwen_approved_model_bytes,
        )
        if not os.access(registry_path, os.R_OK):
            raise PolicyError(f"approved model registry cannot be opened: {registry_path}")
        fields = _read_approved_registry_row(
            registry_path, qwen_approved_model_id, qwen_approved_model_file
        )
        approved_fields = fields
        registry_selector = qwen_approved_model_id
    else:
        _verify_ordinary_model_path(model, model_root)
        registry_selector = model

    def registry_value(name: str) -> str | None:
        if approved_fields is not None:
            return approved_fields.get(name)
        return registry_field(registry_path, "path", registry_selector, name)

    size_text = str(context_size)
    if not _is_decimal(size_text) or int(size_text) == 0:
        raise PolicyError("context size must be a positive integer")
    resolved_context_size = int(size_text)

    # `--n-predict` bounds a request that names no max_tokens, and no server
    # argument bounds prompt tokens alone, so the two variables bound one
    # combined budget clamped against --ctx-size rather than two ceilings.
    for name, value in (
        ("QWEN_LAN_MAX_PROMPT_TOKENS", qwen_lan_max_prompt_tokens),
        ("QWEN_LAN_MAX_OUTPUT_TOKENS", qwen_lan_max_output_tokens),
    ):
        if value and not _positive_decimal(value):
            raise PolicyError(f"{name} must be a positive integer: {value}")
    if bool(qwen_lan_max_prompt_tokens) != bool(qwen_lan_max_output_tokens):
        raise PolicyError(
            "QWEN_LAN_MAX_PROMPT_TOKENS and QWEN_LAN_MAX_OUTPUT_TOKENS share one "
            "context window and are set together or not at all"
        )
    # Neither bound has a per-section preset field, so admitting them in router
    # mode would push one budget onto every served checkpoint through
    # common_preset::merge.
    if router_enabled and (qwen_lan_max_prompt_tokens or qwen_lan_max_output_tokens):
        raise PolicyError(
            "QWEN_LAN_MAX_PROMPT_TOKENS and QWEN_LAN_MAX_OUTPUT_TOKENS have no "
            "per-section preset field, so router mode refuses them rather than "
            "pushing one budget onto every served checkpoint"
        )
    lan_bounds = LanBounds(
        prompt_tokens=int(qwen_lan_max_prompt_tokens) if qwen_lan_max_prompt_tokens else None,
        output_tokens=int(qwen_lan_max_output_tokens) if qwen_lan_max_output_tokens else None,
    )

    launch_tuple: LaunchTuple | None = None
    resolved_row: ResolvedRow | None = None
    cache_type_k = DEFAULT_CACHE_TYPE_K
    cache_type_v = DEFAULT_CACHE_TYPE_V
    flash_attention = DEFAULT_FLASH_ATTENTION
    batch_size = DEFAULT_BATCH
    ubatch_size = DEFAULT_UBATCH
    registry_model_id = ""
    if not router_enabled:
        # The admitted depth is a property of the checkpoint rather than of the
        # appliance: KV cost scales with full-attention layer count and
        # key-value head width. A checkpoint outside the registry keeps the
        # depth the 24K allocation of 2,974 MiB was measured against.
        ceiling_text = registry_value("context_ceiling") or ""
        registry_ceiling = (
            int(ceiling_text) if _is_decimal(ceiling_text) else DEFAULT_CONTEXT_CEILING
        )
        registry_cache_k = registry_value("cache_type_k") or DEFAULT_CACHE_TYPE_K
        registry_cache_v = registry_value("cache_type_v") or DEFAULT_CACHE_TYPE_V
        registry_flash = registry_value("flash_attention") or DEFAULT_FLASH_ATTENTION
        cache_type_k = qwen_cache_type_k or registry_cache_k
        cache_type_v = qwen_cache_type_v or registry_cache_v
        flash_attention = qwen_flash_attn or registry_flash
        for cache_type in (cache_type_k, cache_type_v):
            if not validate_cache_type(cache_type):
                raise PolicyError(
                    f"cache type is outside the set llama-server accepts: {cache_type}"
                )
        if flash_attention not in FLASH_ATTENTION_VALUES:
            raise PolicyError(f"flash attention must be on, off, or auto: {flash_attention}")

        # A registry ceiling belongs to the tuple stored in that row, so an
        # experiment changing any member states its own conservative ceiling
        # rather than presenting an unvalidated allocation as admitted policy.
        maximum_context_size = registry_ceiling
        if (
            cache_type_k != registry_cache_k
            or cache_type_v != registry_cache_v
            or flash_attention != registry_flash
        ):
            override = qwen_cache_override_context_ceiling
            if not _positive_decimal(override):
                raise PolicyError(
                    "cache-policy overrides require a positive QWEN_CACHE_OVERRIDE_CONTEXT_CEILING"
                )
            if int(override) > registry_ceiling:
                raise PolicyError(
                    "cache override ceiling must not exceed the registered ceiling: "
                    f"{override} > {registry_ceiling}"
                )
            maximum_context_size = int(override)
        if resolved_context_size > maximum_context_size:
            raise PolicyError(
                "context size exceeds the admitted ceiling for this cache policy: "
                f"{resolved_context_size} > {maximum_context_size}"
            )

        # Submission geometry comes from the row because the ceiling and the
        # geometry are one claim: at 16384 the same tuple wedged the amdgpu
        # compute ring at 2048/512 and completed twice at 128/32.
        registry_batch = registry_value("batch") or ""
        registry_ubatch = registry_value("ubatch") or ""
        batch_text = qwen_batch_size or (
            registry_batch if _is_decimal(registry_batch) else str(DEFAULT_BATCH)
        )
        ubatch_text = qwen_ubatch_size or (
            registry_ubatch if _is_decimal(registry_ubatch) else str(DEFAULT_UBATCH)
        )
        for value in (batch_text, ubatch_text):
            if not _positive_decimal(value):
                raise PolicyError(f"batch and ubatch must be positive integers: {value}")
        batch_size, ubatch_size = int(batch_text), int(ubatch_text)
        if ubatch_size > batch_size:
            raise PolicyError(f"ubatch exceeds batch: {ubatch_size} > {batch_size}")

        # A quarantined profile names a tuple that produced a device failure,
        # and reproducing it resets the compute ring on a live desktop.
        registry_model_id = registry_value("id") or ""
        if registry_model_id:
            quarantine_path = (
                Path(qwen_quarantine_registry)
                if qwen_quarantine_registry
                else directory / "quarantine.tsv"
            )
            profiles = quarantine_rows(quarantine_path, "quarantine-profiles", "standalone")
            hit = [
                row
                for row in profiles
                if row[0] == registry_model_id
                and row[1] == str(resolved_context_size)
                and row[2] == str(batch_size)
                and row[3] == str(ubatch_size)
                and row[4] == cache_type_k
                and row[5] == cache_type_v
                and row[6] == flash_attention
            ]
            if hit:
                raise PolicyError(
                    f"this tuple is quarantined: {registry_model_id} at depth "
                    f"{resolved_context_size}, batch {batch_size}, ubatch {ubatch_size}, "
                    f"K {cache_type_k}, V {cache_type_v}, flash attention {flash_attention}",
                    f"the reason record is evidence/quarantine/{registry_model_id}-"
                    f"d{resolved_context_size}-b{batch_size}-ub{ubatch_size}.md",
                )

        # The allocation and the validated depth are separate claims and the
        # status line carries both, so a served depth above anything measured
        # to fill and decode is a visible gap.
        validated_depth = registry_value("validated_filled_depth") or "-"
        geometry = f"{batch_size}/{ubatch_size}"
        if validated_depth == "-":
            stderr_lines.append(
                f"depth_validation admitted={resolved_context_size} validated=none "
                f"geometry={geometry}"
            )
        elif resolved_context_size > int(validated_depth):
            stderr_lines.append(
                f"depth_validation admitted={resolved_context_size} "
                f"validated={validated_depth} geometry={geometry} "
                "allocation_beyond_validation=yes"
            )
        else:
            stderr_lines.append(
                f"depth_validation admitted={resolved_context_size} "
                f"validated={validated_depth} geometry={geometry}"
            )

        # The clamp only lowers the depth: it runs after every ceiling and
        # validated-depth check has admitted the caller's own value.
        combined = lan_bounds.combined_budget
        if combined is not None:
            resolved_context_size = min(resolved_context_size, combined)
            stderr_lines.append(
                f"lan_resource_bounds prompt_tokens={lan_bounds.prompt_tokens} "
                f"output_tokens={lan_bounds.output_tokens} combined_budget={combined} "
                f"effective_context_size={resolved_context_size}"
            )

    port_text = str(server_port)
    if not _is_decimal(port_text) or not 1024 <= int(port_text) <= 65535:
        raise PolicyError("port must be an integer from 1024 through 65535")
    port = int(port_text)

    if static_path and not Path(static_path, "index.html").is_file():
        raise PolicyError(f"static path must contain index.html: {static_path}")
    # The page's bound tags describe what this argv enforces, and the two are
    # compared rather than trusted: a page stating another value would tell a
    # browser about an enforcement --ctx-size and --n-predict do not perform.
    if static_path:
        try:
            page_bounds = read_page_bounds(Path(static_path, "index.html"))
        except PolicyError as error:
            # The reader is a separate process in the shell, so its own reason
            # reaches stderr ahead of the policy's refusal.
            raise PolicyError(
                *error.messages,
                f"the served page under {static_path} refuses the LAN bound read",
            ) from None
        launch_bounds = lan_bounds.page_form()
        if page_bounds != launch_bounds:
            raise PolicyError(
                f"the served page states {page_bounds} where this launch enforces "
                f"{launch_bounds}: {static_path}/index.html"
            )

    if api_key_file and not (Path(api_key_file).is_file() and Path(api_key_file).stat().st_size):
        raise PolicyError(f"API key file must be a non-empty regular file: {api_key_file}")

    if any(name.startswith("LLAMA_ARG_") for name in ambient):
        raise PolicyError("LLAMA_ARG_* environment overrides are forbidden by the fixed policy")

    # Router mode serves every admitted checkpoint behind one listener.
    # models-max is 1 rather than the upstream 4: the 4B alone peaks at 2029
    # MiB of a 2048 MiB VRAM carve-out with 2700 MiB more in GTT, so a second
    # resident model competes for a pool one already saturates.
    presets = (
        Path(qwen_router_presets)
        if qwen_router_presets
        else paths["qwen_home_state"] / "router-presets.ini"
    )
    quarantine_registry = (
        Path(qwen_quarantine_registry) if qwen_quarantine_registry else directory / "quarantine.tsv"
    )
    draft_pair_registry = (
        Path(qwen_draft_pairs) if qwen_draft_pairs else directory / "draft-pairs.tsv"
    )
    ctx_checkpoint_ledger = (
        Path(qwen_ctx_checkpoint_ledger)
        if qwen_ctx_checkpoint_ledger
        else directory / "ctx-checkpoints.tsv"
    )
    q4k_policy_rows, q4k_policy_identity = _q4k_policy(qwen_bundle_q4k_policy)

    def verify_preset_identity() -> None:
        if not qwen_router_preset_sha256:
            return
        if len(qwen_router_preset_sha256) != 64 or _HEX64.match(qwen_router_preset_sha256) is None:
            raise PolicyError("router preset SHA-256 must hold 64 lowercase hexadecimal characters")
        measured = _measure_authority("router preset", presets)
        if measured != qwen_router_preset_sha256:
            raise PolicyError(
                f"router preset identity changed: expected {qwen_router_preset_sha256}, "
                f"measured {measured}"
            )

    router_state: _RouterState | None = None
    preset_section_names: tuple[str, ...] = ()
    checkpoint_manifest_sha256 = "-"
    preset_guard_sha256 = registry_guard_sha256 = quarantine_guard_sha256 = "-"
    draft_pair_guard_sha256 = ctx_checkpoint_guard_sha256 = "-"
    if router_enabled:
        if not os.access(presets, os.R_OK):
            raise PolicyError(
                f"router presets are unreadable: {presets}",
                "generate them with remote/build-router-presets.sh",
            )
        verify_preset_identity()
        if not os.access(registry_path, os.R_OK):
            raise PolicyError(f"router model registry is unreadable: {registry_path}")
        if not os.access(quarantine_registry, os.R_OK):
            raise PolicyError(f"router quarantine authority is unavailable: {quarantine_registry}")
        if not _is_decimal(qwen_router_max):
            raise PolicyError(
                f"router model limit must be a non-negative integer: {qwen_router_max}"
            )
        # The head marker is the file's own provenance, which is what makes the
        # section resolution survive a preset persisting across a later launch.
        web_whole_file = _marker(presets, "# qwen_web_presets=")
        if web_whole_file == "":
            web_whole_file = "0"
        elif web_whole_file not in ("0", "1"):
            raise PolicyError(f"router presets carry ambiguous web provenance: {presets}")
        web_sections = _marker(presets, "# qwen_web_sections=")
        if web_sections in ("", "-"):
            web_sections = ""
        elif (
            any(character not in _WEB_SECTION_CHARACTERS for character in web_sections)
            or web_sections.startswith(",")
            or web_sections.endswith(",")
            or ",," in web_sections
        ):
            raise PolicyError(f"router presets carry a malformed web section list: {web_sections}")
        if web_whole_file == "1" and web_sections:
            raise PolicyError(
                "router presets claim both a whole-file web provenance and a web "
                f"section list: {presets}"
            )
        web_mode = web_whole_file == "1" or bool(web_sections)

        image_profile = _marker(presets, "# qwen_image_profile=")
        if image_profile in ("", "-"):
            image_profile = ""
        elif not image_profile[0].isascii() or not image_profile[0].isalnum():
            raise PolicyError(
                f"router presets carry a malformed image profile marker: {image_profile}"
            )
        elif any(
            not (character.isascii() and (character.isalnum() or character in "._-"))
            for character in image_profile
        ):
            # image-registry.sh's identifier() admits a period after the first
            # character, so a ledger-valid id such as sdxs.512-arm-a passes.
            raise PolicyError(
                f"router presets carry a malformed image profile marker: {image_profile}"
            )
        image_profiles = _marker(presets, "# qwen_image_profiles_path=")
        image_profiles_sha256 = _marker(presets, "# qwen_image_profiles_sha256=")
        if image_profile:
            if not image_profiles.startswith("/"):
                raise PolicyError(
                    f"router presets name image profile {image_profile} and omit an "
                    f"absolute image ledger path: {presets}"
                )
            if len(image_profiles_sha256) != 64 or _HEX64.match(image_profiles_sha256) is None:
                raise PolicyError(
                    "image preset ledger SHA-256 must hold 64 lowercase hexadecimal characters"
                )
            # An image server reaches the device from a section the web ledger
            # emitted, so a lane armed over a file naming no web section would
            # sign a grant for a profile the launch never resolves.
            if not web_mode:
                raise PolicyError(
                    f"router presets name image profile {image_profile} and carry no web section"
                )

        web_profiles_path = _marker(presets, "# qwen_web_profiles_path=")
        web_profiles_sha256 = _marker(presets, "# qwen_web_profiles_sha256=")
        web_profiles = directory / "web-profiles.tsv"
        web_profiles_guard_path = "-"
        web_profiles_guard_sha256 = "-"
        web_authorizer_ready = "0"
        if web_mode:
            if not web_profiles_path.startswith("/"):
                raise PolicyError(
                    f"web presets omit an absolute web profile ledger path: {presets}"
                )
            if len(web_profiles_sha256) != 64 or _HEX64.match(web_profiles_sha256) is None:
                raise PolicyError(
                    "web preset ledger SHA-256 must hold 64 lowercase hexadecimal characters"
                )
            if qwen_web_profiles and qwen_web_profiles != web_profiles_path:
                raise PolicyError(
                    f"QWEN_WEB_PROFILES names {qwen_web_profiles} where the preset "
                    f"binds {web_profiles_path}"
                )
            web_profiles = Path(web_profiles_path)
            web_profiles_guard_path = web_profiles_path
            web_profiles_guard_sha256 = web_profiles_sha256
            web_authorizer_ready = qwen_web_authorizer_ready
            if web_authorizer_ready not in ("0", "1"):
                raise PolicyError(
                    f"QWEN_WEB_AUTHORIZER_READY must be 0 or 1: {web_authorizer_ready}"
                )
        elif (web_profiles_path + web_profiles_sha256).replace("\n", "").replace("-", ""):
            # A generation that armed no web lane writes `-` for both, so the
            # markers state their own emptiness rather than being absent.
            raise PolicyError(
                f"non-web router presets carry web profile ledger identity markers: {presets}"
            )

        preset_text = presets.read_text(encoding="utf-8", errors="replace").splitlines()
        web_depth_override = (
            "1" if "# qwen-web-presets: unvalidated-depth-override" in preset_text else "0"
        )
        quarantine_override = "\n".join(
            line[len("# qwen_router_include_quarantine=") :]
            for line in preset_text
            if line.startswith("# qwen_router_include_quarantine=")
            and line[len("# qwen_router_include_quarantine=") :] in ("0", "1")
        )
        if (
            web_whole_file == "0"
            and "# Generated by remote/build-router-presets.sh from the model registry."
            in preset_text
            and quarantine_override == ""
        ):
            raise PolicyError(
                f"generated router presets omit quarantine provenance; regenerate {presets}"
            )
        if quarantine_override not in ("", "0", "1"):
            raise PolicyError(f"router presets carry ambiguous quarantine provenance: {presets}")

        preset_guard_sha256 = qwen_router_preset_sha256 or _measure_authority(
            "router preset", presets
        )
        registry_guard_sha256 = _measure_authority("router model registry", registry_path)
        quarantine_guard_sha256 = _measure_authority(
            "router quarantine registry", quarantine_registry
        )
        draft_pair_guard_path = "-"
        draft_pair_guard_sha256 = "-"
        if web_whole_file != "1":
            draft_pair_guard_path = str(draft_pair_registry)
            draft_pair_guard_sha256 = _measure_authority(
                "router draft-pair ledger", draft_pair_registry
            )

        router_state = _RouterState(
            presets=presets,
            registry=registry_path,
            quarantine_registry=quarantine_registry,
            draft_pair_registry=draft_pair_registry,
            ctx_checkpoint_ledger=ctx_checkpoint_ledger,
            model_root=model_root,
            web_presets_whole_file=web_whole_file,
            web_sections=web_sections,
            web_mode=web_mode,
            web_profiles=web_profiles,
            web_profiles_guard_path=web_profiles_guard_path,
            web_profiles_guard_sha256=web_profiles_guard_sha256,
            web_authorizer_ready=web_authorizer_ready,
            web_depth_override=web_depth_override,
            quarantine_override=quarantine_override,
            image_profile=image_profile,
            image_profiles=image_profiles,
            image_profiles_sha256=image_profiles_sha256,
            q4k_policy_rows=q4k_policy_rows,
            q4k_policy_identity=q4k_policy_identity,
            draft_pair_guard_path=draft_pair_guard_path,
        )
        stdout_lines.extend(_validate_current_router_authorities(directory, router_state))
        # The digest follows the validation that read the rows, so the guard's
        # remeasurement binds the admitted counts to the ledger content this
        # launch compared each section against.
        ctx_checkpoint_guard_sha256 = _measure_authority(
            "router context checkpoint ledger", ctx_checkpoint_ledger
        )
        if qwen_router_include_quarantine not in ("0", "1"):
            raise PolicyError(
                f"QWEN_ROUTER_INCLUDE_QUARANTINE must be 0 or 1: {qwen_router_include_quarantine}"
            )
        # A quarantined checkpoint reaches the picker only through the research
        # override, and it stays on the loopback while it does. The bind host is
        # forced rather than refused, so the override runs the experiment it
        # exists for and the exposure it would create does not follow it.
        if qwen_router_include_quarantine == "1" or quarantine_override == "1":
            if qwen_web_lan == "1":
                raise PolicyError(
                    "the quarantine override and the LAN exposure name different "
                    "listeners; a checkpoint with a recorded device failure serves "
                    "the loopback"
                )
            if bind_host != "127.0.0.1":
                stderr_lines.append(
                    f"quarantine override forces the listener to loopback: {bind_host} -> 127.0.0.1"
                )
                bind_host = "127.0.0.1"
        # A section admitted past its validated_filled_depth serves a depth no
        # run has filled and decoded, so the same restriction applies.
        if web_depth_override == "1":
            if qwen_web_lan == "1":
                raise PolicyError(
                    "the unvalidated-depth override and the LAN exposure name "
                    "different listeners; validate the depth or serve it on the loopback"
                )
            if bind_host != "127.0.0.1":
                stderr_lines.append(
                    "web preset unvalidated-depth override forces the listener to "
                    f"loopback: {bind_host} -> 127.0.0.1"
                )
                bind_host = "127.0.0.1"
        preset_section_names = tuple(
            entry.name for entry in _parse_preset(presets, []) if entry.name not in ("", "*")
        )
        argv = [
            server,
            "--models-preset",
            str(presets),
            "--models-max",
            qwen_router_max,
            "--host",
            bind_host,
            "--port",
            str(port),
            "--cors-origins",
            qwen_cors_origins,
        ]
    else:
        argv = [
            server,
            "--model",
            model,
            "--host",
            bind_host,
            "--port",
            str(port),
            "--alias",
            "qwen-apu",
            "--cors-origins",
            qwen_cors_origins,
        ]

    # `--path` mounts a directory at the server root and `--ui` alone serves the
    # asset table `tools/ui/embed.cpp` compiles into the binary, so the staged
    # page and the built-in page are the two exclusive surfaces of one flag
    # pair: `server-http.cpp` registers the embedded routes in the `else` branch
    # that an empty `public_path` selects. A launch that stages a page keeps it,
    # `ui` alone asks for the built-in surface, and neither leaves the server
    # reading llama.cpp's default `--path` value.
    if static_path:
        argv += ["--path", static_path, "--ui"]
    elif ui:
        argv.append("--ui")
    else:
        argv.append("--no-ui")
    if api_key_file:
        argv += ["--api-key-file", api_key_file]

    # The projector turns images into embeddings the language model consumes,
    # and it must come from the same checkpoint as the language weights.
    if qwen_mmproj and not router_enabled:
        if not Path(qwen_mmproj).is_file():
            raise PolicyError(f"projector is not a regular file: {qwen_mmproj}")
        argv += ["--mmproj", qwen_mmproj]
        if qwen_mmproj_offload == "0":
            argv.append("--no-mmproj-offload")
        if qwen_image_max_tokens:
            argv += ["--image-max-tokens", qwen_image_max_tokens]

    # Speculation is a policy argument rather than an ambient override, so
    # these four variables are the whole surface while LLAMA_ARG_* stays
    # refused. `off` is the explicit disable a harness exports, and it selects
    # the same argv the absent variable does.
    spec_type = "" if qwen_spec_type == "off" else qwen_spec_type
    if spec_type:
        if spec_type not in SPEC_TYPE_VALUES:
            raise PolicyError(f"speculation type must be draft-mtp or an ngram type: {spec_type}")
        argv += ["--spec-type", spec_type]
        if qwen_spec_draft_n_max:
            if not _is_decimal(qwen_spec_draft_n_max):
                raise PolicyError(
                    f"draft length must be a non-negative integer: {qwen_spec_draft_n_max}"
                )
            # A draft of N tokens makes the target emit N+1 output positions in
            # one pass, and common_speculative_get_output_limits clamps that
            # count to the batch size.
            if int(qwen_spec_draft_n_max) > 16:
                raise PolicyError(
                    f"draft length exceeds operational maximum: {qwen_spec_draft_n_max} > 16"
                )
            # Zero aborts the pinned server on the first prompt:
            # common_speculative_get_output_limits sizes the target context for
            # `1 + n_draft` outputs while the speculative decode path asks for
            # two, and llama-context.cpp:2227 asserts the pair.
            if int(qwen_spec_draft_n_max) == 0:
                raise PolicyError(
                    "draft length of zero aborts the pinned server; omit "
                    "QWEN_SPEC_TYPE to disable speculation"
                )
            argv += ["--spec-draft-n-max", qwen_spec_draft_n_max]
        # p_min gates drafting rather than acceptance: common/speculative.cpp
        # breaks out of the draft loop when the head's confidence falls below
        # it, so a floor of 1 leaves the block loaded and nothing drafted.
        spec_p_min = "" if qwen_spec_draft_p_min == "0" else qwen_spec_draft_p_min
        if spec_p_min:
            if (
                any(character not in "0123456789." for character in spec_p_min)
                or spec_p_min.count(".") > 1
            ):
                raise PolicyError(
                    f"draft probability floor must be a decimal fraction: {spec_p_min}"
                )
            argv += ["--spec-draft-p-min", spec_p_min]
        if qwen_spec_backend_sampling == "1":
            argv.append("--spec-draft-backend-sampling")

    # Backend sampling moves the supported sampler chain onto the device. The
    # vocabulary is 248,320 entries wide, so the transfer it removes is the
    # largest per-token host copy the server makes.
    if qwen_backend_sampling == "1":
        argv.append("--backend-sampling")

    # Context checkpoints are the one saved-state mechanism a hybrid recurrent
    # model has: server-context.cpp cannot roll the Gated DeltaNet state back.
    # The count is per registry row, and a row outside the ledger serves at 0.
    registry_ctx_checkpoints = "0"
    if not router_enabled:
        registry_model_id = registry_value("id") or ""
        if registry_model_id:
            try:
                rows = ctx_checkpoint_rows(ctx_checkpoint_ledger, registry_path)
            except PolicyError:
                raise PolicyError("context checkpoint authority is unavailable") from None
            matched = [row[1] for row in rows if row[0] == registry_model_id]
            registry_ctx_checkpoints = matched[-1] if matched else "0"
    ctx_checkpoints_text = qwen_ctx_checkpoints or registry_ctx_checkpoints
    if not _is_decimal(ctx_checkpoints_text):
        raise PolicyError(
            f"context checkpoint count must be a non-negative integer: {ctx_checkpoints_text}"
        )
    # Router mode takes its count from each section, so this variable would
    # reach neither the argv nor the preset.
    if router_enabled and qwen_ctx_checkpoints:
        raise PolicyError(
            f"QWEN_CTX_CHECKPOINTS is refused in router mode: {qwen_ctx_checkpoints}",
            "launch the checkpoint the arm measures on the single-model path",
        )
    ctx_checkpoints = int(ctx_checkpoints_text)
    if qwen_checkpoint_min_step:
        if not _is_decimal(qwen_checkpoint_min_step):
            raise PolicyError(
                "checkpoint minimum step must be a non-negative integer: "
                f"{qwen_checkpoint_min_step}"
            )
        # The spacing reaches the router's own argv and common_preset::merge
        # overwrites, so one value would place every child's checkpoints while
        # each section still matched the ledger.
        if router_enabled:
            raise PolicyError(
                f"QWEN_CHECKPOINT_MIN_STEP is refused in router mode: {qwen_checkpoint_min_step}",
                "launch the checkpoint the arm measures on the single-model path",
            )

    # A positive count is meaningful only against a build whose prompt fill
    # loop places checkpoints at natural n_batch boundaries. The ledger and the
    # binary are separate release artifacts, so the build declares what it
    # compiled and an absent declaration refuses rather than defaults.
    checkpoint_semantics = "unknown"
    manifest_path: Path | None = None
    server_directory = Path(os.path.realpath(server)).parent
    for candidate in (
        server_directory / "artifact-manifest.tsv",
        server_directory.parent / "artifact-manifest.tsv",
    ):
        if not os.access(candidate, os.R_OK):
            continue
        # A manifest states the declaration once, so a second row leaves the
        # value undefined rather than disputed.
        declarations = [
            fields[1]
            for fields in _raw_rows(candidate)
            if fields and fields[0] == "checkpoint_semantics" and len(fields) > 1
        ]
        checkpoint_semantics = (
            declarations[0] if len(declarations) == 1 and declarations[0] != "" else "unknown"
        )
        checkpoint_manifest_sha256 = _sha256_file(candidate)
        manifest_path = candidate
        break

    # Router mode carries the count per section, so the preset rather than this
    # argv states whether any child arms one.
    if router_enabled:
        armed = False
        if os.access(presets, os.R_OK):
            for line in presets.read_text(encoding="utf-8", errors="replace").splitlines():
                match = re.match(r"^[ \t]*LLAMA_ARG_CTX_CHECKPOINTS[ \t]*=[ \t]*(.*?)[ \t]*$", line)
                if match and _as_number(match.group(1)) > 0:
                    armed = True
    else:
        armed = ctx_checkpoints > 0
    checkpoint_guard_requirement = "natural-boundary-v1" if armed else "-"
    # The refusal is stated here so an unserviceable combination fails while
    # the reason is readable beside the argv it would have produced;
    # qwen-build-exec-guard.sh states it again at the exec boundary.
    if "-" != checkpoint_guard_requirement != checkpoint_semantics:
        raise PolicyError(
            f"the selected llama-server declares checkpoint_semantics="
            f"{checkpoint_semantics}: {server}",
            f"a positive context checkpoint count requires {checkpoint_guard_requirement}",
        )
    stdout_lines.append(
        f"checkpoint_binding semantics={checkpoint_semantics} "
        f"requirement={checkpoint_guard_requirement} "
        f"manifest_sha256={checkpoint_manifest_sha256}"
    )

    # The Q4_K mat-vec formulation the launch serves, and the build authority
    # that admits it. QWEN_Q4K_VARIANT is the experiment route and precedence
    # is stated rather than inferred: an ambient value that differs from the
    # row replaces the released selection only under QWEN_Q4K_EXPERIMENT_ARM=1.
    if qwen_q4k_experiment_arm not in ("0", "1"):
        raise PolicyError(f"QWEN_Q4K_EXPERIMENT_ARM must be 0 or 1: {qwen_q4k_experiment_arm}")
    registry_q4k_variant = "-"
    if not router_enabled:
        registry_q4k_variant = registry_value("q4k_variant") or "-"
        if not validate_q4k_variant(registry_q4k_variant):
            raise PolicyError(
                f"the registry row carries q4k_variant {registry_q4k_variant}, "
                "which is outside the vocabulary"
            )
    q4k_selection = registry_q4k_variant
    q4k_selection_source = "registry"
    if qwen_q4k_variant:
        if not validate_q4k_variant(qwen_q4k_variant):
            raise PolicyError(f"QWEN_Q4K_VARIANT is outside the vocabulary: {qwen_q4k_variant}")
        # Router mode reads the key off each section, so an environment value
        # would reach every child through the environ snapshot
        # server-models.cpp spawns from.
        if router_enabled:
            raise PolicyError(
                f"QWEN_Q4K_VARIANT is refused in router mode: {qwen_q4k_variant}",
                "launch the checkpoint the arm measures on the single-model path",
            )
        if qwen_q4k_variant != registry_q4k_variant and qwen_q4k_experiment_arm != "1":
            raise PolicyError(
                f"QWEN_Q4K_VARIANT names {qwen_q4k_variant} where the registry row "
                f"releases {registry_q4k_variant}",
                "set QWEN_Q4K_EXPERIMENT_ARM=1 to measure a formulation the row does not release",
            )
        q4k_selection = qwen_q4k_variant
        q4k_selection_source = "environment"

    q4k_guard_requirement = "-"
    if router_enabled:
        if os.access(presets, os.R_OK):
            keys: list[str] = []
            for line in presets.read_text(encoding="utf-8", errors="replace").splitlines():
                match = re.match(r"^[ \t]*LLAMA_ARG_VK_Q4K_VARIANT[ \t]*=[ \t]*(.*?)[ \t]*$", line)
                if match and match.group(1) != "" and match.group(1) not in keys:
                    keys.append(match.group(1))
            q4k_guard_requirement = ",".join(keys) if keys else "-"
    elif q4k_selection != "-":
        q4k_guard_requirement = q4k_selection

    q4k_declared_variants = "-"
    if q4k_guard_requirement != "-":
        if manifest_path is None:
            raise PolicyError(
                f"the selected llama-server carries no artifact manifest: {server}",
                "a Q4_K formulation key requires a build declaring q4k_variants",
            )
        declared = [
            fields[1]
            for fields in _raw_rows(manifest_path)
            if fields and fields[0] == "q4k_variants" and len(fields) > 1
        ]
        q4k_declared_variants = declared[0] if len(declared) == 1 and declared[0] != "" else "-"
        admitted = set(q4k_declared_variants.split(",")) if q4k_declared_variants != "-" else set()
        unadmitted = [
            key for key in q4k_guard_requirement.split(",") if key and key not in admitted
        ]
        if unadmitted:
            raise PolicyError(
                *[
                    f"the selected llama-server does not admit Q4_K formulation {key}"
                    for key in unadmitted
                ],
                f"the build declares q4k_variants={q4k_declared_variants}: {server}",
            )
    stdout_lines.append(
        f"q4k_binding selection={q4k_selection} source={q4k_selection_source} "
        f"requirement={q4k_guard_requirement} declared={q4k_declared_variants}"
    )

    # radv-low-priority-env.sh scrubs GGML_VK_Q4K_VARIANT and re-exports it
    # from this name alone, so the released selection reaches pipeline creation
    # through the one route past the scrub.
    environment_additions: dict[str, str] = {}
    environment_removals: list[str] = []
    if not router_enabled and q4k_selection != "-":
        environment_additions["QWEN_Q4K_VARIANT"] = q4k_selection
    else:
        environment_removals.append("QWEN_Q4K_VARIANT")

    argv += [
        "--log-verbosity",
        "4",
        "--device",
        "Vulkan0",
        "--split-mode",
        "none",
        "--n-gpu-layers",
        "all",
        "--override-tensor",
        ".*=Vulkan0",
        "--fit",
        "off",
        "--parallel",
        "1",
        "--threads",
        "1",
        "--threads-batch",
        "1",
        "--cache-ram",
        "0",
        "--no-context-shift",
        "--offline",
    ]
    if qwen_checkpoint_min_step:
        argv += ["--checkpoint-min-step", qwen_checkpoint_min_step]

    # The six per-checkpoint flags stay off the router's own argv, because
    # server-models.cpp ends its preset assembly with `preset.merge(base_preset)`
    # and common_preset::merge overwrites. The checkpoint count joins them for
    # the same reason, with a default of 32 where the ledger admits at most two.
    if not router_enabled:
        argv += [
            "--ctx-checkpoints",
            str(ctx_checkpoints),
            "--ctx-size",
            str(resolved_context_size),
            "--batch-size",
            str(batch_size),
            "--ubatch-size",
            str(ubatch_size),
            "--flash-attn",
            flash_attention,
            "--cache-type-k",
            cache_type_k,
            "--cache-type-v",
            cache_type_v,
        ]
        if lan_bounds.output_tokens is not None:
            argv += ["--n-predict", str(lan_bounds.output_tokens)]
        # A checkpoint outside the registry resolves no row, and the plan
        # says so rather than naming a row built from the fallbacks.
        if registry_model_id:
            resolved_row = ResolvedRow(
                id=registry_model_id,
                model_file=registry_value("model_file") or "",
                context_ceiling=str(registry_ceiling),
                cache_type_k=registry_cache_k,
                cache_type_v=registry_cache_v,
                flash_attention=registry_flash,
                batch=registry_value("batch") or str(DEFAULT_BATCH),
                ubatch=registry_value("ubatch") or str(DEFAULT_UBATCH),
                validated_filled_depth=validated_depth,
                q4k_variant=registry_q4k_variant,
            )
        launch_tuple = LaunchTuple(
            context_size=resolved_context_size,
            batch=batch_size,
            ubatch=ubatch_size,
            flash_attention=flash_attention,
            cache_type_k=cache_type_k,
            cache_type_v=cache_type_v,
            ctx_checkpoints=ctx_checkpoints,
        )

    # The appliance admits one active qwen-owned Vulkan workload, and the
    # kernel lock under the state directory carries it. radv-low-priority-env.sh
    # scrubs the GGML_VK_, display, AMD, RADV, and VK layer names alone, so this
    # variable crosses the exec boundary untouched.
    lease_directory = Path(
        qwen_webui_state_directory if qwen_webui_state_directory else paths["qwen_home_state"]
    )
    lease_directory.mkdir(parents=True, exist_ok=True)
    lease_directory.chmod(0o700)
    lease_path = lease_directory / "vulkan-workload.lock"
    if qwen_vulkan_external_lease_proof:
        verifier = directory / "verify-external-vulkan-lease.py"
        if not os.access(verifier, os.X_OK):
            raise PolicyError(f"external Vulkan lease verifier is absent: {verifier}")
        completed = subprocess.run(
            [str(verifier), qwen_vulkan_external_lease_proof, str(lease_path)],
            check=False,
            capture_output=True,
            text=True,
        )
        if completed.returncode != 0:
            raise PolicyError(*completed.stderr.splitlines())
        environment_removals.append("QWEN_VULKAN_WORKLOAD_LOCK")
        stdout_lines.append(
            f"vulkan_workload_lease mode=external path={lease_path} "
            f"proof={qwen_vulkan_external_lease_proof}"
        )
    else:
        environment_additions["QWEN_VULKAN_WORKLOAD_LOCK"] = str(lease_path)
        stdout_lines.append(f"vulkan_workload_lease mode=request path={lease_path}")

    # The launcher hashes its immutable-per-session snapshot before preflight,
    # and the exec boundary revalidates every mutable authority, so a
    # replacement of any ledger invalidates the assembled command.
    exec_argv = [
        str(directory / "radv-low-priority-env.sh"),
        str(directory / "qwen-build-exec-guard.sh"),
        server,
        checkpoint_manifest_sha256,
        checkpoint_guard_requirement,
        q4k_guard_requirement,
    ]
    if router_enabled:
        assert router_state is not None
        verify_preset_identity()
        stdout_lines.extend(_validate_current_router_authorities(directory, router_state))
        # A file holding the admitted rows at each validation and revoked rows
        # at the single measurement would hand the guard a digest naming
        # content no validation read.
        final_sha256 = _measure_authority("router context checkpoint ledger", ctx_checkpoint_ledger)
        if final_sha256 != ctx_checkpoint_guard_sha256:
            raise PolicyError(
                "context checkpoint ledger identity changed during validation: expected "
                f"{ctx_checkpoint_guard_sha256}, measured {final_sha256}"
            )
        exec_argv += [
            str(directory / "qwen-router-exec-guard.sh"),
            str(presets),
            preset_guard_sha256,
            str(registry_path),
            registry_guard_sha256,
            str(quarantine_registry),
            quarantine_guard_sha256,
            router_state.draft_pair_guard_path,
            draft_pair_guard_sha256,
            router_state.web_profiles_guard_path,
            router_state.web_profiles_guard_sha256,
            str(ctx_checkpoint_ledger),
            ctx_checkpoint_guard_sha256,
            q4k_guard_requirement,
        ]
    exec_argv += argv

    return LaunchPlan(
        argv=tuple(argv),
        exec_argv=tuple(exec_argv),
        environment_additions=environment_additions,
        environment_removals=tuple(environment_removals),
        mode="router" if router_enabled else "standalone",
        model_id=registry_model_id or None,
        model_row=resolved_row,
        launch_tuple=launch_tuple,
        bind_host=bind_host,
        port=port,
        preset_path=presets if router_enabled else None,
        preset_section_names=preset_section_names,
        ctx_checkpoints=ctx_checkpoints,
        q4k_variant=q4k_selection,
        q4k_selection_source=q4k_selection_source,
        lan_bounds=lan_bounds,
        checkpoint_semantics=checkpoint_semantics,
        checkpoint_guard_requirement=checkpoint_guard_requirement,
        checkpoint_manifest_sha256=checkpoint_manifest_sha256,
        q4k_guard_requirement=q4k_guard_requirement,
        stdout_lines=tuple(stdout_lines),
        stderr_lines=tuple(stderr_lines),
    )


_ENVIRONMENT_KEYWORDS: tuple[tuple[str, str, str], ...] = (
    ("QWEN_ROUTER", "qwen_router", "0"),
    ("QWEN_BIND_HOST", "qwen_bind_host", "127.0.0.1"),
    ("QWEN_CORS_ORIGINS", "qwen_cors_origins", "localhost"),
    ("QWEN_WEB_LAN", "qwen_web_lan", "0"),
    ("QWEN_WEB_LAN_OPEN", "qwen_web_lan_open", "0"),
    ("QWEN_APPROVED_MODEL_ID", "qwen_approved_model_id", ""),
    ("QWEN_APPROVED_MODEL_FILE", "qwen_approved_model_file", ""),
    ("QWEN_APPROVED_MODEL_DEVICE", "qwen_approved_model_device", ""),
    ("QWEN_APPROVED_MODEL_INODE", "qwen_approved_model_inode", ""),
    ("QWEN_APPROVED_MODEL_BYTES", "qwen_approved_model_bytes", ""),
    ("QWEN_MODEL_REGISTRY", "qwen_model_registry", ""),
    ("QWEN_MODEL_ROOT", "qwen_model_root", ""),
    ("QWEN_QUARANTINE_REGISTRY", "qwen_quarantine_registry", ""),
    ("QWEN_DRAFT_PAIRS", "qwen_draft_pairs", ""),
    ("QWEN_CTX_CHECKPOINT_LEDGER", "qwen_ctx_checkpoint_ledger", ""),
    ("QWEN_LAN_MAX_PROMPT_TOKENS", "qwen_lan_max_prompt_tokens", ""),
    ("QWEN_LAN_MAX_OUTPUT_TOKENS", "qwen_lan_max_output_tokens", ""),
    ("QWEN_CACHE_TYPE_K", "qwen_cache_type_k", ""),
    ("QWEN_CACHE_TYPE_V", "qwen_cache_type_v", ""),
    ("QWEN_FLASH_ATTN", "qwen_flash_attn", ""),
    ("QWEN_CACHE_OVERRIDE_CONTEXT_CEILING", "qwen_cache_override_context_ceiling", ""),
    ("QWEN_BATCH_SIZE", "qwen_batch_size", ""),
    ("QWEN_UBATCH_SIZE", "qwen_ubatch_size", ""),
    ("QWEN_ROUTER_PRESETS", "qwen_router_presets", ""),
    ("QWEN_ROUTER_PRESET_SHA256", "qwen_router_preset_sha256", ""),
    ("QWEN_ROUTER_MAX", "qwen_router_max", "1"),
    ("QWEN_ROUTER_INCLUDE_QUARANTINE", "qwen_router_include_quarantine", "0"),
    ("QWEN_WEB_PROFILES", "qwen_web_profiles", ""),
    ("QWEN_WEB_AUTHORIZER_READY", "qwen_web_authorizer_ready", "0"),
    ("QWEN_BUNDLE_Q4K_POLICY", "qwen_bundle_q4k_policy", ""),
    ("QWEN_MMPROJ", "qwen_mmproj", ""),
    ("QWEN_MMPROJ_OFFLOAD", "qwen_mmproj_offload", "1"),
    ("QWEN_IMAGE_MAX_TOKENS", "qwen_image_max_tokens", ""),
    ("QWEN_SPEC_TYPE", "qwen_spec_type", ""),
    ("QWEN_SPEC_DRAFT_N_MAX", "qwen_spec_draft_n_max", ""),
    ("QWEN_SPEC_DRAFT_P_MIN", "qwen_spec_draft_p_min", ""),
    ("QWEN_SPEC_BACKEND_SAMPLING", "qwen_spec_backend_sampling", "0"),
    ("QWEN_BACKEND_SAMPLING", "qwen_backend_sampling", "0"),
    ("QWEN_CTX_CHECKPOINTS", "qwen_ctx_checkpoints", ""),
    ("QWEN_CHECKPOINT_MIN_STEP", "qwen_checkpoint_min_step", ""),
    ("QWEN_Q4K_VARIANT", "qwen_q4k_variant", ""),
    ("QWEN_Q4K_EXPERIMENT_ARM", "qwen_q4k_experiment_arm", "0"),
    ("QWEN_WEBUI_STATE_DIRECTORY", "qwen_webui_state_directory", ""),
    ("QWEN_VULKAN_EXTERNAL_LEASE_PROOF", "qwen_vulkan_external_lease_proof", ""),
)


def plan_from_environment(
    arguments: Sequence[str],
    environ: Mapping[str, str],
    script_directory: Path | None = None,
) -> LaunchPlan:
    """`build_launch_plan` driven the way the shell is: positional argv and the environment.

    Each `${NAME:-default}` in the script becomes one keyword here, so an
    unset name and an empty one both read as the default, which is the
    behavior of that expansion.
    """
    if not 3 <= len(arguments) <= 6:
        raise PolicyError(USAGE)
    # Every expanded keyword is one environment string, and `ui` is a bool the
    # Python lane sets rather than an environment name this table carries, so
    # the mapping is annotated where it is built rather than at the call.
    keywords: dict[str, Any] = {
        keyword: environ.get(name) or fallback for name, keyword, fallback in _ENVIRONMENT_KEYWORDS
    }
    return build_launch_plan(
        arguments[0],
        arguments[1],
        arguments[2],
        arguments[3] if len(arguments) > 3 else "8080",
        arguments[4] if len(arguments) > 4 else "",
        arguments[5] if len(arguments) > 5 else "",
        script_directory=script_directory,
        environ=environ,
        **keywords,
    )
