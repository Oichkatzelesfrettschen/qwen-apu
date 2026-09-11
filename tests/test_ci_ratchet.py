"""Each ratchet rule fires on the violation it names and stays quiet on a
clean tree; the real worktree root carries zero violations."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from qwen_apu.ci.ratchet import (
    RatchetGrowthError,
    rewrite_baseline,
    rule_new_shell,
    rule_outside_root,
    rule_shell_true,
    rule_string_command,
    rule_sudo,
    run,
)

TREE = Path(__file__).resolve().parents[1]


def _git(root: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)


def _init_repo(root: Path) -> None:
    _git(root, "init", "-q")
    _git(root, "-c", "user.email=test@example.com", "-c", "user.name=test", "add", "-A")


def _write_module(root: Path, relative: str, content: str) -> None:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


# -- new-shell -----------------------------------------------------------


def test_new_shell_rule_fires_on_untracked_script(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(tmp_path, "config/shell-baseline.txt", "")
    (tmp_path / "foo.sh").write_text("#!/bin/sh\necho hi\n", encoding="utf-8")
    _git(tmp_path, "add", "-A")

    violations = rule_new_shell(tmp_path)

    assert len(violations) == 1
    assert violations[0].path == "foo.sh"
    assert violations[0].rule == "new-shell"


def test_new_shell_rule_quiet_when_baselined(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(tmp_path, "config/shell-baseline.txt", "foo.sh\n")
    (tmp_path / "foo.sh").write_text("#!/bin/sh\necho hi\n", encoding="utf-8")
    _git(tmp_path, "add", "-A")

    assert rule_new_shell(tmp_path) == []


def test_new_shell_rule_quiet_for_stale_baseline_entry(tmp_path: Path) -> None:
    """A baseline entry for a file that no longer exists is not a violation;
    the ratchet only tightens."""
    _init_repo(tmp_path)
    _write_module(tmp_path, "config/shell-baseline.txt", "gone.sh\n")
    _git(tmp_path, "add", "-A")

    assert rule_new_shell(tmp_path) == []


def test_rewrite_baseline_shrinks(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(tmp_path, "config/shell-baseline.txt", "gone.sh\nkeep.sh\n")
    (tmp_path / "keep.sh").write_text("#!/bin/sh\n", encoding="utf-8")
    _git(tmp_path, "add", "-A")

    rewrite_baseline(tmp_path)

    assert (tmp_path / "config" / "shell-baseline.txt").read_text(encoding="utf-8") == "keep.sh\n"


def test_rewrite_baseline_refuses_growth(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(tmp_path, "config/shell-baseline.txt", "keep.sh\n")
    (tmp_path / "keep.sh").write_text("#!/bin/sh\n", encoding="utf-8")
    (tmp_path / "new.sh").write_text("#!/bin/sh\n", encoding="utf-8")
    _git(tmp_path, "add", "-A")

    with pytest.raises(RatchetGrowthError):
        rewrite_baseline(tmp_path)
    assert (tmp_path / "config" / "shell-baseline.txt").read_text(encoding="utf-8") == "keep.sh\n"


# -- shell-true ------------------------------------------------------------


def test_shell_true_rule_fires_on_shell_keyword(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(
        tmp_path,
        "src/qwen_apu/sample/mod.py",
        "import subprocess\n\nsubprocess.run(['ls'], shell=True)\n",
    )
    _git(tmp_path, "add", "-A")

    violations = rule_shell_true(tmp_path)

    assert len(violations) == 1
    assert violations[0].rule == "shell-true"
    assert violations[0].path == "src/qwen_apu/sample/mod.py"


def test_shell_true_rule_fires_on_create_subprocess_shell(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(
        tmp_path,
        "src/qwen_apu/sample/mod.py",
        "import asyncio\n\nasyncio.create_subprocess_shell('ls')\n",
    )
    _git(tmp_path, "add", "-A")

    violations = rule_shell_true(tmp_path)

    assert len(violations) == 1
    assert violations[0].rule == "shell-true"


def test_shell_true_rule_quiet_on_argv_list(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(
        tmp_path,
        "src/qwen_apu/sample/mod.py",
        "import subprocess\n\nsubprocess.run(['ls', '-l'])\n",
    )
    _git(tmp_path, "add", "-A")

    assert rule_shell_true(tmp_path) == []


# -- string-command ----------------------------------------------------


def test_string_command_rule_fires_on_string_literal(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(
        tmp_path,
        "src/qwen_apu/sample/mod.py",
        "import subprocess\n\nsubprocess.run('ls -l')\n",
    )
    _git(tmp_path, "add", "-A")

    violations = rule_string_command(tmp_path)

    assert len(violations) == 1
    assert violations[0].rule == "string-command"


def test_string_command_rule_fires_on_fstring(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(
        tmp_path,
        "src/qwen_apu/sample/mod.py",
        "import subprocess\n\ntarget = 'x'\nsubprocess.call(f'echo {target}')\n",
    )
    _git(tmp_path, "add", "-A")

    violations = rule_string_command(tmp_path)

    assert len(violations) == 1
    assert violations[0].rule == "string-command"


def test_string_command_rule_quiet_on_argv_list(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(
        tmp_path,
        "src/qwen_apu/sample/mod.py",
        "import subprocess\n\nsubprocess.run(['ls', '-l'])\n",
    )
    _git(tmp_path, "add", "-A")

    assert rule_string_command(tmp_path) == []


# -- sudo ----------------------------------------------------------------


def test_sudo_rule_fires_on_string_constant(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(tmp_path, "src/qwen_apu/sample/mod.py", 'COMMAND = "sudo reboot"\n')
    _git(tmp_path, "add", "-A")

    violations = rule_sudo(tmp_path)

    assert len(violations) == 1
    assert violations[0].rule == "sudo"


def test_sudo_rule_quiet_in_research_admin(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(tmp_path, "src/qwen_apu/research_admin/mod.py", 'COMMAND = "sudo reboot"\n')
    _git(tmp_path, "add", "-A")

    assert rule_sudo(tmp_path) == []


def test_sudo_rule_fires_on_os_system_anywhere_under_src(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(
        tmp_path,
        "src/qwen_apu/research_admin/mod.py",
        "import os\n\nos.system('ls')\n",
    )
    _git(tmp_path, "add", "-A")

    violations = rule_sudo(tmp_path)

    assert len(violations) == 1
    assert violations[0].message.startswith("os.system")


def test_sudo_rule_quiet_on_unrelated_string(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(tmp_path, "src/qwen_apu/sample/mod.py", 'GREETING = "hello"\n')
    _git(tmp_path, "add", "-A")

    assert rule_sudo(tmp_path) == []


# -- outside-root ----------------------------------------------------------


def _write_allowlist(root: Path) -> None:
    _write_module(
        root,
        "runtime/appliance-path-allowlist.tsv",
        "prefix\treason\n/etc/os-release\tsystem fact\n",
    )


def test_outside_root_rule_fires(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_allowlist(tmp_path)
    _write_module(tmp_path, "src/qwen_apu/sample/mod.py", 'CACHE = "/opt/qwen/cache"\n')
    _git(tmp_path, "add", "-A")

    violations = rule_outside_root(tmp_path)

    assert len(violations) == 1
    assert violations[0].rule == "outside-root"


def test_outside_root_rule_honors_allowlist_and_named_marker(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_allowlist(tmp_path)
    _write_module(
        tmp_path,
        "src/qwen_apu/sample/mod.py",
        'ALLOWED = "/etc/os-release"\nNAMED = "/opt/refused/on/purpose"  # appliance-path: named\n',
    )
    _git(tmp_path, "add", "-A")

    assert rule_outside_root(tmp_path) == []


def test_outside_root_rule_skips_fixture_marker(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_allowlist(tmp_path)
    _write_module(
        tmp_path,
        "src/qwen_apu/sample/mod.py",
        '# appliance-path: fixtures\nBAD = "/opt/should/be/skipped"\n',
    )
    _git(tmp_path, "add", "-A")

    assert rule_outside_root(tmp_path) == []


def test_outside_root_rule_quiet_without_allowlist(tmp_path: Path) -> None:
    _init_repo(tmp_path)
    _write_module(tmp_path, "src/qwen_apu/sample/mod.py", 'BAD = "/opt/should/not/matter"\n')
    _git(tmp_path, "add", "-A")

    assert rule_outside_root(tmp_path) == []


# -- the real worktree ------------------------------------------------------


def test_real_worktree_is_clean() -> None:
    violations = run(TREE)
    assert violations == [], "\n".join(violation.render() for violation in violations)
