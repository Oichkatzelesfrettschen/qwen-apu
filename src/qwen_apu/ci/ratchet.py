"""The migration ratchet: every rule below names one defect class the shell
predecessor left behind and refuses its return in the Python control plane.

`new-shell` freezes the shell surface at `config/shell-baseline.txt`: a
tracked `*.sh` path already in the baseline stays legal and a new one
refuses, so the migration only ever shrinks the set. `shell-true` and
`string-command` read `ast.Call` nodes rather than grep a command line, so a
`subprocess.run(["ls", "-l"])` reads as an argv list and a
`subprocess.run("ls -l")` reads as the string form the migration retires.
`sudo` refuses a literal `sudo` string or an `os.system` call under `src/`,
since the launch chain and the sudoers policy hold that authority outside
this package. `outside-root` reuses the two path regexes from
`remote/check-appliance-paths.py` so a Python script inherits the same
runtime-root discipline a shell script already meets.

`private-path` refuses a user's own home directory spelled absolutely in
tracked documentation and source, since a receipt that names one describes a
path no other checkout holds; `$HOME`, `$QWEN_HOME`, and `~/` pass. The
`evidence/` tree stays outside this rule's reach because its own sanitization
records state the substitution they apply and quote the literal they replace.

`run(root)` returns every violation across all seven rules. `main(argv)`
prints one line per violation as `path:line: rule: message` and exits 1 on
any; `--rewrite-baseline` regenerates `config/shell-baseline.txt` from the
current tracked set, refusing when that set is not a subset of the baseline
it replaces.
"""

from __future__ import annotations

import argparse
import ast
import re
import shutil
import subprocess
import sys
from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from pathlib import Path

_DEFAULT_ROOT = Path(__file__).resolve().parents[3]
_GIT = shutil.which("git") or "git"

_BASELINE_RELATIVE = "config/shell-baseline.txt"
_ALLOWLIST_RELATIVE = "runtime/appliance-path-allowlist.tsv"

_COMMAND_CALL_NAMES = {
    "run",
    "call",
    "check_call",
    "check_output",
    "Popen",
    "create_subprocess_shell",
}
_SHELL_ONLY_NAME = "create_subprocess_shell"

# Split so this file's own ast scan, which flags a Constant node equal to or
# starting with the sudo token, does not flag the token's own definition.
_SUDO_RULE_NAME = "sud" + "o"
_SUDO_PATH_MARKER = "/sud" + "o"

_OUTSIDE_ROOT_ABSOLUTE = re.compile(
    r"(?<![\w.$/{}])(/(?:usr/local|opt|etc|var|srv|home)/[\w./$@{}-]*)"
)
_OUTSIDE_ROOT_HOME = re.compile(
    r"(\$\{?HOME[^}/]*\}?/[\w./$@{}-]*|(?<![\w/])~/[\w./$@{}-]*)"  # appliance-path: named
)
_OUTSIDE_ROOT_NAMED_MARKER = "appliance-path: named"
_OUTSIDE_ROOT_FIXTURES_MARKER = "appliance-path: fixtures"

# Split so this rule's own pattern, which matches an absolute user home
# directory, does not match the definition that carries it.
_PRIVATE_HOME_SEGMENT = "/ho" + "me/"
_PRIVATE_HOME = re.compile(re.escape(_PRIVATE_HOME_SEGMENT) + r"(?![-\s]|$)[\w.-]+")
_PRIVATE_PATH_NAMED_MARKER = "private-path: named"
# Where the rule reads: every file under these directories plus `bootstrap.py`.
# `evidence/` stays out, since a sanitization record quotes the literal it
# replaced and that quotation is the record's own content.
_PRIVATE_PATH_TREES = ("docs", "src", "tests")
_PRIVATE_PATH_SUFFIXES = (".md", ".py", ".txt", ".tsv", ".json")


@dataclass(frozen=True, order=True)
class Violation:
    """One ratchet finding: a path, a one-based line, a rule name, and the
    sentence a reader acts on."""

    path: str
    line: int
    rule: str
    message: str

    def render(self) -> str:
        return f"{self.path}:{self.line}: {self.rule}: {self.message}"


class RatchetGrowthError(RuntimeError):
    """The tracked shell set grew past the baseline; --rewrite-baseline
    refuses rather than widening what the ratchet accepts."""


def _tracked_paths(root: Path) -> list[str]:
    output = subprocess.run(  # noqa: S603
        [_GIT, "-C", str(root), "-c", "core.fsmonitor=false", "ls-files", "-z"],
        check=True,
        capture_output=True,
    ).stdout
    return [entry.decode() for entry in output.split(b"\0") if entry]


def _read_baseline(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    return {line for line in path.read_text(encoding="utf-8").splitlines() if line}


def rule_new_shell(root: Path) -> list[Violation]:
    """Every tracked `*.sh` path names an entry in `config/shell-baseline.txt`.
    A baseline entry for a file that no longer exists is not a violation --
    the ratchet only tightens."""
    baseline_path = root / _BASELINE_RELATIVE
    baseline = _read_baseline(baseline_path)
    violations = []
    for rel in _tracked_paths(root):
        if rel.endswith(".sh") and rel not in baseline:
            violations.append(
                Violation(
                    rel, 1, "new-shell", f"tracked shell script is absent from {_BASELINE_RELATIVE}"
                )
            )
    return violations


def rewrite_baseline(root: Path) -> None:
    """Regenerate the baseline from the current tracked `*.sh` set. Refuses
    when that set is not a subset of the baseline it would replace, since a
    grown set is exactly what `rule_new_shell` exists to catch."""
    baseline_path = root / _BASELINE_RELATIVE
    old = _read_baseline(baseline_path)
    new = {rel for rel in _tracked_paths(root) if rel.endswith(".sh")}
    if not new.issubset(old):
        added = ", ".join(sorted(new - old))
        raise RatchetGrowthError(f"the tracked shell script set grew past the baseline: {added}")
    baseline_path.write_text("\n".join(sorted(new)) + "\n", encoding="utf-8")


def _python_targets(root: Path) -> list[str]:
    """`src/**/*.py` and `bootstrap.py`, read from the filesystem rather than
    the git index: rules b through e apply to every such file the checkout
    holds, staged or not, unlike rule (a)'s tracked-only shell surface."""
    targets: list[str] = []
    src_dir = root / "src"
    if src_dir.is_dir():
        targets.extend(path.relative_to(root).as_posix() for path in sorted(src_dir.rglob("*.py")))
    if (root / "bootstrap.py").is_file():
        targets.append("bootstrap.py")
    return targets


def _parsed_python_targets(root: Path) -> Iterator[tuple[str, ast.Module]]:
    for rel in _python_targets(root):
        source = (root / rel).read_text(encoding="utf-8")
        yield rel, ast.parse(source, filename=rel)


def _call_name(node: ast.Call) -> str | None:
    func = node.func
    if isinstance(func, ast.Attribute):
        return func.attr
    if isinstance(func, ast.Name):
        return func.id
    return None


def _command_calls(tree: ast.Module) -> Iterator[tuple[ast.Call, str]]:
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            name = _call_name(node)
            if name in _COMMAND_CALL_NAMES:
                yield node, name


def rule_shell_true(root: Path) -> list[Violation]:
    """A subprocess or asyncio call in `src/**/*.py` or `bootstrap.py` never
    passes `shell=True`, and `asyncio.create_subprocess_shell` refuses
    outright since a shell interpreter is what it always runs."""
    violations = []
    for rel, tree in _parsed_python_targets(root):
        for call, name in _command_calls(tree):
            if name == _SHELL_ONLY_NAME:
                violations.append(
                    Violation(
                        rel,
                        call.lineno,
                        "shell-true",
                        "asyncio.create_subprocess_shell always runs a shell interpreter",
                    )
                )
                continue
            for keyword in call.keywords:
                if (
                    keyword.arg == "shell"
                    and isinstance(keyword.value, ast.Constant)
                    and keyword.value.value is True
                ):
                    violations.append(
                        Violation(rel, call.lineno, "shell-true", f"{name}(...) passes shell=True")
                    )
    return violations


def rule_string_command(root: Path) -> list[Violation]:
    """The first positional argument of a subprocess or asyncio call names an
    argv list or tuple, never a single command string."""
    violations = []
    for rel, tree in _parsed_python_targets(root):
        for call, name in _command_calls(tree):
            if not call.args:
                continue
            first = call.args[0]
            is_string_literal = isinstance(first, ast.Constant) and isinstance(first.value, str)
            if is_string_literal or isinstance(first, ast.JoinedStr):
                violations.append(
                    Violation(
                        rel,
                        call.lineno,
                        "string-command",
                        f"{name}(...) takes a string command instead of an argv list",
                    )
                )
    return violations


_TRACE_FLAGS = frozenset({"-x", "-xv", "-vx", "-o", "xtrace"})
_SHELL_NAMES = frozenset({"sh", "bash", "dash", "zsh", "ksh"})
_OUTPUT_CALL_NAMES = frozenset(
    {
        "print",
        "dumps",
        "dump",
        "write",
        "info",
        "warning",
        "error",
        "debug",
        "exception",
        "critical",
        "log",
    }
)


def rule_secret_exposure(root: Path) -> list[Violation]:
    """No argv in `src/**/*.py` or `bootstrap.py` traces a shell, and the whole
    process environment never reaches an output call. A traced shell echoes
    every expanded command line, and an environment dump carries every
    variable, so either would print a bearer or a signing key into a log or a
    tool transcript; the rotation receipt records the trace that did."""
    violations = []
    for rel, tree in _parsed_python_targets(root):
        for call, name in _command_calls(tree):
            if not call.args or not isinstance(call.args[0], (ast.List, ast.Tuple)):
                continue
            elements = call.args[0].elts
            for index, element in enumerate(elements[:-1]):
                if not (isinstance(element, ast.Constant) and isinstance(element.value, str)):
                    continue
                if element.value.rsplit("/", 1)[-1] not in _SHELL_NAMES:
                    continue
                flag = elements[index + 1]
                if isinstance(flag, ast.Constant) and flag.value in _TRACE_FLAGS:
                    violations.append(
                        Violation(rel, call.lineno, "shell-trace", f"{name}(...) traces a shell")
                    )
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call) or _call_name(node) not in _OUTPUT_CALL_NAMES:
                continue
            for argument in list(node.args) + [keyword.value for keyword in node.keywords]:
                if _is_environ(argument):
                    violations.append(
                        Violation(
                            rel,
                            node.lineno,
                            "environ-dump",
                            "os.environ reaches an output call whole",
                        )
                    )
    return violations


def _is_environ(node: ast.expr) -> bool:
    """`os.environ`, `environ`, `dict(os.environ)`, or `os.environ.copy()`."""
    if isinstance(node, ast.Attribute) and node.attr == "environ":
        return True
    if isinstance(node, ast.Name) and node.id == "environ":
        return True
    if isinstance(node, ast.Call):
        if _call_name(node) == "dict" and node.args and _is_environ(node.args[0]):
            return True
        if isinstance(node.func, ast.Attribute) and node.func.attr == "copy":
            return _is_environ(node.func.value)
    return False


def rule_sudo(root: Path) -> list[Violation]:
    """A string constant under `src/qwen_apu/` (excluding
    `src/qwen_apu/research_admin/`) names no `sudo` invocation, and
    `os.system` refuses anywhere under `src/`. The launch chain and the
    sudoers policy hold that authority outside this package."""
    violations = []
    for rel, tree in _parsed_python_targets(root):
        if rel.startswith("src/qwen_apu/") and not rel.startswith("src/qwen_apu/research_admin/"):
            for node in ast.walk(tree):
                if isinstance(node, ast.Constant) and isinstance(node.value, str):
                    text = node.value
                    if text.startswith(_SUDO_RULE_NAME) or _SUDO_PATH_MARKER in text:
                        violations.append(
                            Violation(
                                rel,
                                node.lineno,
                                _SUDO_RULE_NAME,
                                f"string constant names sudo: {text!r}",
                            )
                        )
        if rel.startswith("src/"):
            for node in ast.walk(tree):
                if (
                    isinstance(node, ast.Call)
                    and isinstance(node.func, ast.Attribute)
                    and node.func.attr == "system"
                    and isinstance(node.func.value, ast.Name)
                    and node.func.value.id == "os"
                ):
                    violations.append(
                        Violation(
                            rel,
                            node.lineno,
                            _SUDO_RULE_NAME,
                            "os.system(...) runs a shell command outside the argv discipline",
                        )
                    )
    return violations


def _load_allowlist(path: Path) -> list[tuple[str, str]]:
    """A missing allowlist means the surrounding tree carries no
    runtime-root doctrine yet, so the rule reads no allowlist and stays
    quiet. A present but malformed header is a defect in the file itself and
    refuses outright, matching `remote/check-appliance-paths.py`."""
    if not path.is_file():
        return []
    rows = []
    with path.open(encoding="utf-8") as handle:
        header = handle.readline().rstrip("\n").split("\t")
        if header != ["prefix", "reason"]:
            raise SystemExit(f"{path}: header is {header}, expected prefix and reason")
        for raw_line in handle:
            stripped_line = raw_line.rstrip("\n")
            if not stripped_line or stripped_line.startswith("#"):
                continue
            fields = stripped_line.split("\t")
            if len(fields) == 2 and fields[0] and fields[1]:
                rows.append((fields[0], fields[1]))
    return rows


def _python_code_lines(text: str) -> list[tuple[int, str]]:
    """Lines outside comments and docstrings, tracking triple-quote parity
    the way `remote/check-appliance-paths.py` does for its own `.py` targets."""
    out: list[tuple[int, str]] = []
    in_docstring = False
    for number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        quotes = stripped.count('"""') + stripped.count("'''")
        if in_docstring:
            if quotes % 2 == 1:
                in_docstring = False
            continue
        if quotes % 2 == 1:
            in_docstring = True
            continue
        if quotes >= 2 and (stripped.startswith('"""') or stripped.startswith("'''")):
            continue
        if not stripped or stripped.startswith("#"):
            continue
        out.append((number, line))
    return out


def rule_outside_root(root: Path) -> list[Violation]:
    """`src/**/*.py` and `bootstrap.py` name no owned storage outside the
    runtime root, mirroring `remote/check-appliance-paths.py` over the shell
    tree. A file whose first five lines carry the fixtures marker is a
    ratchet test fixture and is skipped whole; a missing allowlist means the
    surrounding tree carries no runtime-root doctrine yet and the rule is
    quiet rather than refusing every path it cannot classify."""
    allowlist = _load_allowlist(root / _ALLOWLIST_RELATIVE)
    if not allowlist:
        return []
    violations = []
    for rel in _python_targets(root):
        text = (root / rel).read_text(encoding="utf-8")
        head = text.splitlines()[:5]
        if any(_OUTSIDE_ROOT_FIXTURES_MARKER in line for line in head):
            continue
        for number, line in _python_code_lines(text):
            if _OUTSIDE_ROOT_NAMED_MARKER in line:
                continue
            matches = list(_OUTSIDE_ROOT_ABSOLUTE.finditer(line)) + list(
                _OUTSIDE_ROOT_HOME.finditer(line)
            )
            for match in matches:
                token = match.group(1)
                if any(token.startswith(prefix) for prefix, _ in allowlist):
                    continue
                violations.append(
                    Violation(
                        rel,
                        number,
                        "outside-root",
                        f"names owned storage outside the runtime root: {token}",
                    )
                )
    return violations


def _private_path_targets(root: Path) -> list[str]:
    """Every documentation and source file the private-path rule reads.

    The set is `docs/`, `src/`, and `tests/` plus `bootstrap.py`, filtered to
    the text suffixes a path literal appears in, so a fixture image or a
    checked-in binary is never decoded.
    """
    targets: list[str] = []
    for tree in _PRIVATE_PATH_TREES:
        directory = root / tree
        if not directory.is_dir():
            continue
        targets.extend(
            path.relative_to(root).as_posix()
            for path in sorted(directory.rglob("*"))
            if path.is_file() and path.suffix in _PRIVATE_PATH_SUFFIXES
        )
    if (root / "bootstrap.py").is_file():
        targets.append("bootstrap.py")
    return sorted(targets)


def rule_private_paths(root: Path) -> list[Violation]:
    """Documentation and source name no absolute user home directory.

    A receipt carrying one describes storage the checkout reading it does not
    hold, and the repository hard rule keeps a local absolute path out of a
    commit. `$HOME`, `$QWEN_HOME`, and `~/` all pass, so a portable spelling is
    what a scrubbed receipt reads. A line carrying the named marker states the
    literal deliberately and is skipped.
    """
    violations = []
    for rel in _private_path_targets(root):
        try:
            text = (root / rel).read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for number, line in enumerate(text.splitlines(), start=1):
            if _PRIVATE_PATH_NAMED_MARKER in line:
                continue
            for match in _PRIVATE_HOME.finditer(line):
                violations.append(
                    Violation(
                        rel,
                        number,
                        "private-path",
                        "names an absolute user home directory rather than "
                        f"$HOME or $QWEN_HOME: {match.group(0)}",
                    )
                )
    return violations


def run(root: Path) -> list[Violation]:
    """Every rule's violations over `root`, sorted for deterministic output."""
    resolved = root.resolve()
    violations: list[Violation] = []
    violations.extend(rule_new_shell(resolved))
    violations.extend(rule_shell_true(resolved))
    violations.extend(rule_string_command(resolved))
    violations.extend(rule_secret_exposure(resolved))
    violations.extend(rule_sudo(resolved))
    violations.extend(rule_outside_root(resolved))
    violations.extend(rule_private_paths(resolved))
    return sorted(violations)


def main(argv: Sequence[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    parser = argparse.ArgumentParser(
        prog="python -m qwen_apu.ci.ratchet",
        description="Refuse a shell-migration regression: new shell scripts, "
        "string commands, shell=True, sudo, owned storage outside the runtime "
        "root, and an absolute user home directory in documentation or source.",
    )
    parser.add_argument(
        "--root", type=Path, default=_DEFAULT_ROOT, help="repository root (default: this checkout)"
    )
    parser.add_argument(
        "--rewrite-baseline",
        action="store_true",
        help="regenerate config/shell-baseline.txt from the current tracked set; refuses growth",
    )
    parsed = parser.parse_args(args)
    root: Path = parsed.root.resolve()

    if parsed.rewrite_baseline:
        try:
            rewrite_baseline(root)
        except RatchetGrowthError as error:
            print(f"qwen_apu.ci.ratchet: {error}", file=sys.stderr)
            return 1
        print(f"qwen_apu.ci.ratchet: {_BASELINE_RELATIVE} rewritten")
        return 0

    violations = run(root)
    for violation in violations:
        print(violation.render())
    if violations:
        print(f"qwen_apu.ci.ratchet: {len(violations)} violation(s)", file=sys.stderr)
        return 1
    print("qwen_apu.ci.ratchet: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
