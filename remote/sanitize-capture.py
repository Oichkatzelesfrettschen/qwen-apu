#!/usr/bin/env python3
"""Sanitize one acquisition file into the tree and report both digests.

`remote/retain-acquisition.sh` copies a whole acquisition directory under the
repository's three substitutions -- the private hostname to `qwen-laptop`, the
serving user's home prefix to `$HOME`, and a MAC address to `<mac>` -- and
writes `transformation.tsv` beside the copy. A capture read over `ssh cat`
arrives as one file at a path of the caller's choosing rather than as a
directory tree, so this reader applies the identical substitutions to one file
and prints the row a `transformation.tsv` carries.

It adds one field the shell script has no equivalent of. A transformation
record states what the retained bytes came from and leaves open which rules
produced them, so `sanitizer_sha256` names the digest of this file: a later
edit to a pattern changes that value, and a retained record therefore binds its
substitutions to the reader that made them.

The source is read and never written. The output path is refused where it
resolves to the input or to any existing file, because a sanitizer that
overwrites its own input destroys the digest its record claims and one that
overwrites an existing output leaves a record describing bytes a later run
replaced.

A file whose content is not text passes through byte-for-byte and reports
`binary` as its substitution count, since substituting inside a register dump,
a VBIOS image, or a compiled module would corrupt the artifact the digest
identifies. The text test is `grep -I`'s own: a file carrying a NUL byte is
binary, and an empty file is text.

usage: sanitize-capture.py RAW_PATH OUTPUT_PATH
  QWEN_SANITIZE_HOST  private hostname replaced by `qwen-laptop`, default the
                      appliance name this tree records
  QWEN_SANITIZE_HOME  home prefix replaced by the literal `$HOME`, default the
                      invoking user's own
"""

from __future__ import annotations

import hashlib
import os
import re
import sys
from pathlib import Path

DEFAULT_SANITIZE_HOST = "hp14-dk1xxx"

# A MAC is six colon-separated hexadecimal pairs bounded by a character that is
# neither hexadecimal nor a colon, so a longer colon-separated hexadecimal run
# such as an IPv6 literal or a digest broken into pairs stays untouched.
MAC_PATTERN = r"(?<![0-9A-Fa-f:])(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}(?![0-9A-Fa-f:])"


class SanitizeError(RuntimeError):
    """Report an input this reader refuses."""


def substitution_rules(host: str, home: str) -> tuple[tuple[str, str], ...]:
    """Return the ordered patterns `retain-acquisition.sh` applies."""
    return (
        (re.escape(host), "qwen-laptop"),
        (re.escape(home), "$HOME"),
        (MAC_PATTERN, "<mac>"),
    )


def is_text(payload: bytes) -> bool:
    """Return whether `grep -I` reads these bytes as text.

    `grep -qI .` treats a file carrying a NUL byte as binary and requires one
    line holding a character other than the newline; the shell script admits an
    empty file separately, so an empty payload is text here.
    """
    if not payload:
        return True
    if b"\x00" in payload:
        return False
    return any(line for line in payload.split(b"\n"))


def sanitize_text(text: str, rules: tuple[tuple[str, str], ...]) -> tuple[str, int]:
    """Return the substituted text and the count of substitutions made."""
    substitutions = 0
    for pattern, replacement in rules:
        text, count = re.subn(pattern, replacement, text)
        substitutions += count
    return text, substitutions


def sanitize_file(
    raw_path: Path, output_path: Path, rules: tuple[tuple[str, str], ...]
) -> tuple[str, str, str]:
    """Write the sanitized copy and return both digests and the count.

    The count is the literal `binary` where the payload passes through, which
    is the value `transformation.tsv` already carries for such a file.
    """
    payload = raw_path.read_bytes()
    raw_digest = hashlib.sha256(payload).hexdigest()
    if is_text(payload):
        text = payload.decode("utf-8", errors="surrogateescape")
        sanitized, count = sanitize_text(text, rules)
        written = sanitized.encode("utf-8", errors="surrogateescape")
        substitutions = str(count)
    else:
        written = payload
        substitutions = "binary"
    # An exclusive create refuses an existing output at the filesystem rather
    # than after a stat, so a file appearing between the check and the write is
    # refused too.
    with open(output_path, "xb") as handle:
        handle.write(written)
    return raw_digest, hashlib.sha256(written).hexdigest(), substitutions


def resolve_refusals(raw_path: Path, output_path: Path) -> None:
    """Refuse an output that is the input or that already exists."""
    if not raw_path.is_file():
        raise SanitizeError(f"the raw capture is absent: {raw_path}")
    if output_path.exists():
        raise SanitizeError(f"the output already exists: {output_path}")
    resolved_raw = raw_path.resolve()
    # The output does not exist, so `strict` stays off and the parent decides.
    if output_path.resolve() == resolved_raw:
        raise SanitizeError(f"the output resolves to the input: {output_path}")


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"usage: {Path(argv[0]).name} RAW_PATH OUTPUT_PATH", file=sys.stderr)
        return 2

    raw_path = Path(argv[1])
    output_path = Path(argv[2])
    host = os.environ.get("QWEN_SANITIZE_HOST", DEFAULT_SANITIZE_HOST)
    home = os.environ.get("QWEN_SANITIZE_HOME", os.environ.get("HOME", ""))
    if not home:
        print("the home prefix to sanitize is unset", file=sys.stderr)
        return 2

    try:
        resolve_refusals(raw_path, output_path)
        sanitizer_digest = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        raw_digest, sanitized_digest, substitutions = sanitize_file(
            raw_path, output_path, substitution_rules(host, home)
        )
    except (SanitizeError, OSError) as error:
        print(f"sanitize-capture: {error}", file=sys.stderr)
        return 2

    print("\t".join((raw_digest, sanitized_digest, sanitizer_digest, substitutions)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
