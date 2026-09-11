"""The one TSV reader every ledger in remote/ shares.

remote/model-registry.sh, remote/check-validated-tuples.sh, and their sibling
readers each parse a ledger with `awk -F'\\t'`, skip a `#`-prefixed or blank
line, and refuse a row whose field count disagrees with the header. This
module is that mechanism in one place, so a ledger's shape is checked once
and src/qwen_apu/config/models.py builds typed rows over an already-validated
table rather than re-deriving the shape rule per ledger.
"""

from __future__ import annotations

import os
import re
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

_HEADER_IDENTIFIER = re.compile(r"^[a-z][a-z0-9_]*$")


class RegistryError(ValueError):
    """A ledger row, header, or cross-ledger reference fails its own rule.

    The message repeats the wording remote/model-registry.sh and its sibling
    shell readers print to stderr on the same refusal, so a caller comparing
    Python's error against the shell's reads one text rather than two.
    """


def tree_root() -> Path:
    """The repository root a checkout's own layout implies.

    `src/qwen_apu/config/loader.py` sits four segments below the root, the
    same distance `remote/model-registry.sh` computes with
    `dirname -- "$0"` and one `..`.
    """
    return Path(__file__).resolve().parents[3]


def remote_dir() -> Path:
    return tree_root() / "remote"


def default_ledger_path(name: str) -> Path:
    return remote_dir() / f"{name}.tsv"


@dataclass(frozen=True, slots=True)
class LedgerTable:
    """A validated TSV ledger: its header columns and every data row in file order."""

    path: Path
    columns: tuple[str, ...]
    rows: tuple[tuple[int, tuple[str, ...]], ...]


def _is_header_line(line: str) -> tuple[str, ...] | None:
    """Return a header's column names when every field is a lowercase identifier.

    remote/models.tsv carries many `#` comment lines before its own header;
    the header is the one whose fields all read as lowercase snake_case
    names, and the last such line wins where a ledger's comment block quotes
    column names inside prose (none observed to date, but the rule matches
    what the shell readers assume by construction: one header line, whatever
    else precedes it).
    """
    body = line[1:].strip("\n")
    if not body.startswith("\t") and "\t" not in body:
        return None
    fields = body.split("\t")
    if not fields or any(not _HEADER_IDENTIFIER.match(field.strip()) for field in fields):
        return None
    return tuple(field.strip() for field in fields)


def read_ledger(
    path: Path,
    *,
    key_index: int = 0,
    key_fn: Callable[[tuple[str, ...]], str] | None = None,
) -> LedgerTable:
    """Parse one TSV ledger: header from the last well-formed `#` header line, data after.

    Refuses (`RegistryError`) a ledger with no such header, a data row whose
    field count differs from the header's, and a data row whose key --
    `fields[key_index]`, or `key_fn(fields)` where a ledger's identity is a
    composite of several columns (remote/feature-claims.tsv keys on
    `(subject_id, feature)`, since one subject_id repeats across many
    feature rows) -- repeats an earlier row's. The same three refusals
    remote/model-registry.sh's `validate_*_ledger` functions apply to the
    tuple, draft-pair, and context-checkpoint ledgers, generalized to every
    ledger this package reads.
    """
    if not path.is_file():
        raise RegistryError(f"ledger is unreadable: {path}")
    text = path.read_text(encoding="utf-8")
    header: tuple[str, ...] | None = None
    rows: list[tuple[int, tuple[str, ...]]] = []
    seen_keys: set[str] = set()
    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        if raw_line.strip() == "":
            continue
        if raw_line.startswith("#"):
            candidate = _is_header_line(raw_line)
            if candidate is not None:
                header = candidate
            continue
        if header is None:
            raise RegistryError(
                f"{path}: line {line_number} precedes any header line "
                "of lowercase, tab-separated column names"
            )
        fields = tuple(raw_line.split("\t"))
        if len(fields) != len(header):
            raise RegistryError(
                f"{path}: row {line_number} holds {len(fields)} fields, expected {len(header)}"
            )
        key = key_fn(fields) if key_fn is not None else fields[key_index]
        if key in seen_keys:
            raise RegistryError(f"{path}: duplicate key {key!r} at row {line_number}")
        seen_keys.add(key)
        rows.append((line_number, fields))
    if header is None:
        raise RegistryError(f"{path}: no header line of lowercase, tab-separated column names")
    return LedgerTable(path=path, columns=header, rows=tuple(rows))


def require_columns(table: LedgerTable, expected: tuple[str, ...]) -> None:
    """Refuse a ledger whose header names differ from the schema this reader expects.

    A shape mismatch here means the TSV and the dataclass in schema.py have
    drifted, which every other check in this package assumes has not
    happened.
    """
    if table.columns != expected:
        raise RegistryError(
            f"{table.path}: header columns {table.columns} do not match "
            f"the expected columns {expected}"
        )


def resolve_ledger_path(explicit: Path | str | None, env_var: str, name: str) -> Path:
    """The path a ledger reads from: an explicit argument, then an env override, then the default.

    Mirrors `${QWEN_..._REGISTRY:-$script_directory/NAME.tsv}` in
    remote/model-registry.sh and its siblings: an explicit caller-supplied
    path wins outright (the shell readers have no equivalent, since every
    shell caller reaches a non-default ledger through the environment
    variable alone), then the named environment variable, then the
    repository-relative default.
    """
    if explicit is not None:
        return Path(explicit)
    env_value = os.environ.get(env_var)
    if env_value:
        return Path(env_value)
    return default_ledger_path(name)


def sentinel_to_optional_str(value: str) -> str | None:
    """`-` is the ledger sentinel for "no claim"; every other value passes through."""
    return None if value == "-" else value


def sentinel_to_optional_int(value: str, *, field_name: str, row_key: str) -> int | None:
    if value == "-":
        return None
    if not re.fullmatch(r"(0|[1-9][0-9]*)", value):
        raise RegistryError(
            f"{row_key}: {field_name} is not a canonical non-negative integer: {value}"
        )
    return int(value)


def sentinel_to_optional_float(value: str, *, field_name: str, row_key: str) -> float | None:
    if value == "-":
        return None
    try:
        return float(value)
    except ValueError as exc:
        raise RegistryError(f"{row_key}: {field_name} is not numeric: {value}") from exc


def require_repository_relative_evidence_path(value: str, *, field_name: str, row_key: str) -> None:
    """Refuse an evidence path the shell's `case` pattern refuses as unsafe.

    remote/model-registry.sh reads each retained evidence path as one shell
    word after AWK has fixed the row shape and tests it with the shell
    pathname primitive `case ... in '' | - | .. | /* | ../* | */../* | */..)`,
    which keeps a ledger's quotes, semicolons, and command substitutions
    outside executable input. This is that same closed set of unsafe shapes,
    read as pure string comparison since Python evaluates no ledger text as
    code to begin with.
    """
    if value in {"", "-", ".."}:
        raise RegistryError(f"{row_key}: {field_name} is not a repository-relative path: {value}")
    if value.startswith("/") or value.startswith("../"):
        raise RegistryError(f"{row_key}: {field_name} is not a repository-relative path: {value}")
    if "/../" in value or value.endswith("/.."):
        raise RegistryError(f"{row_key}: {field_name} is not a repository-relative path: {value}")


def require_canonical_int(
    value: str, *, field_name: str, row_key: str, positive: bool = True
) -> int:
    pattern = r"[1-9][0-9]*" if positive else r"(0|[1-9][0-9]*)"
    if not re.fullmatch(pattern, value):
        kind = "positive" if positive else "non-negative"
        raise RegistryError(f"{row_key}: {field_name} is not a canonical {kind} integer: {value}")
    return int(value)
