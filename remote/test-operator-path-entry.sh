#!/bin/sh
# The PATH entry README.md tells an operator to write, executed as written.
#
# The claim is that the documented block puts `qwen` in the shell an operator
# actually types into. A terminal opened from a desktop session is interactive
# and not a login shell, so it reads `~/.bashrc` and never `~/.profile`, and the
# sourcing runs one way: `~/.profile` reads `~/.bashrc` where the shell is bash
# and nothing reads back. An entry in `~/.profile` alone therefore answers in
# `bash -lc` and refuses in the terminal, which is the failure this test fixes in
# place. The block is read out of README.md rather than copied here, so the
# documentation is the thing under test.
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tree_root=$(CDPATH='' cd -- "$script_directory/.." && pwd -P)
readme=$tree_root/README.md
work_directory=$(mktemp -d)
trap 'rm -rf -- "$work_directory"' EXIT HUP INT TERM
failures=0
report() {
    if [ "$2" = ok ]; then
        printf 'ok %s\n' "$1"
    else
        printf 'FAIL %s: %s\n' "$1" "$2"
        failures=$((failures + 1))
    fi
}

bash_command=$(command -v bash || true)
if [ -z "$bash_command" ]; then
    printf 'operator_path_entry=skipped reason=no bash\n'
    exit 0
fi

# The documented block, from its `case` line through `esac`, with the checkout
# the reader would hold replaced by this one.
awk '/^case ":\$PATH:" in$/, /^esac$/' "$readme" >"$work_directory/block.sh"
if [ ! -s "$work_directory/block.sh" ]; then
    report block_found_in_readme "README.md carries no case block for PATH"
    exit 1
fi
report block_found_in_readme ok
# The block names the checkout a reader would hold, which is the one literal this
# file must carry: the documented text is the subject of the test, so the
# directory is rewritten to this tree rather than derived from qwen-home.sh. The
# `$` reaches sed mid-pattern, where a basic regular expression takes it
# literally.
documented_directory='$HOME/Github/qwen-apu/remote'  # appliance-path: named
sed "s#$documented_directory#$script_directory#g" \
    "$work_directory/block.sh" >"$work_directory/entry.sh"

# ---- the terminal an operator opens: interactive, not a login shell ----
home=$work_directory/home
mkdir -p "$home"
cat "$work_directory/entry.sh" >"$home/.bashrc"
resolved=$(HOME=$home "$bash_command" -i -c 'command -v qwen' 2>/dev/null || true)
[ "$resolved" = "$script_directory/qwen" ] &&
    report interactive_shell_resolves_qwen ok ||
    report interactive_shell_resolves_qwen "${resolved:-not found}"

# ---- the same block in a login shell, and exactly one entry in PATH ----
cat "$work_directory/entry.sh" >"$home/.profile"
resolved=$(HOME=$home "$bash_command" -lc 'command -v qwen' 2>/dev/null || true)
[ "$resolved" = "$script_directory/qwen" ] &&
    report login_shell_resolves_qwen ok ||
    report login_shell_resolves_qwen "${resolved:-not found}"

# A login shell reads `.profile`, which reads `.bashrc`, so both copies run and
# the guard is what keeps the directory from entering PATH twice.
occurrences=$(HOME=$home "$bash_command" -lc 'printf %s "$PATH"' 2>/dev/null |
    tr ':' '\n' | grep -c -- "^$script_directory$" || true)
[ "$occurrences" = 1 ] && report guard_admits_one_entry ok ||
    report guard_admits_one_entry "$occurrences entries"

# ---- an entry in .profile alone is what the terminal refuses ----
rm -f "$home/.bashrc"
if HOME=$home "$bash_command" -i -c 'command -v qwen' >/dev/null 2>&1; then
    report profile_alone_refuses_the_terminal "an interactive shell read .profile"
else
    report profile_alone_refuses_the_terminal ok
fi

[ "$failures" = 0 ] || exit 1
printf 'operator_path_entry=accepted\n'
