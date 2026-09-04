#!/bin/sh
# The path ratchet over a scratch repository: the shipped tree is clean, a
# script naming /usr/local, /opt, /etc, $HOME, or ~/ storage fails with the
# file and line, an allowlisted prefix passes, a comment passes, a marked line
# passes, and a malformed allowlist refuses.
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
checker=$script_directory/check-appliance-paths.py
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
failures=0
report() {
    if [ "$2" = ok ]; then printf 'ok %s\n' "$1"; else printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); fi
}

# ---- the shipped tree ----
PYTHONDONTWRITEBYTECODE=1 python3 "$checker" >"$work/shipped.log" 2>&1 && report shipped_tree_clean ok \
    || report shipped_tree_clean "$(tail -n 3 "$work/shipped.log")"

# ---- a scratch repository ----
repo=$work/repo
mkdir -p "$repo/remote" "$repo/runtime"
git -C "$repo" init -q
printf 'prefix\treason\n/etc/os-release\tdistribution identity\n' >"$repo/runtime/appliance-path-allowlist.tsv"
write_script() {
    printf '%s\n' "$2" >"$repo/remote/$1"
    git -C "$repo" add "remote/$1"
}
run() {
    PYTHONDONTWRITEBYTECODE=1 python3 "$checker" --root "$repo" >"$work/run.log" 2>&1
}

write_script clean.sh 'state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"$qwen_home_state"}
release=$(cat /etc/os-release)
# a comment naming /usr/local/searxng and $HOME/models is prose'
run && report clean_scratch_passes ok || report clean_scratch_passes "$(cat "$work/run.log")"

write_script usr_local.sh 'python=${QWEN_SEARXNG_PYTHON:-/usr/local/searxng/searx-pyenv/bin/python}'
if run; then report usr_local_fails accepted; else
    grep -q 'remote/usr_local.sh:1: /usr/local/searxng/searx-pyenv/bin/python' "$work/run.log" \
        && report usr_local_fails ok || report usr_local_fails "$(cat "$work/run.log")"
fi
git -C "$repo" rm -q --cached remote/usr_local.sh; rm -f "$repo/remote/usr_local.sh"

write_script opt.sh 'root=${QWEN_SEARXNG_ROOT:-/opt/searxng-qwen-apu}'
if run; then report opt_fails accepted; else report opt_fails ok; fi
git -C "$repo" rm -q --cached remote/opt.sh; rm -f "$repo/remote/opt.sh"

write_script home.sh 'models=${QWEN_MODEL_ROOT:-"${HOME:?}/models"}'
if run; then report home_fails accepted; else
    grep -q 'remote/home.sh:1: ${HOME:?}/models' "$work/run.log" && report home_fails ok || report home_fails "$(cat "$work/run.log")"
fi
git -C "$repo" rm -q --cached remote/home.sh; rm -f "$repo/remote/home.sh"

write_script tilde.sh 'destination=${1:-user@host:~/qwen-laptop-setup}'
if run; then report tilde_fails accepted; else report tilde_fails ok; fi
git -C "$repo" rm -q --cached remote/tilde.sh; rm -f "$repo/remote/tilde.sh"

write_script marked.sh 'for legacy in /usr/local/searxng /etc/searxng; do  # appliance-path: named
    printf "%s\n" "$legacy"
done'
run && report marked_line_passes ok || report marked_line_passes "$(cat "$work/run.log")"

write_script module.py '"""Reads ~/src/llama.cpp in prose.

Multi-line docstring naming /opt/rocm.
"""
import os
path = os.environ.get("QWEN_HOME")'
run && report python_docstring_passes ok || report python_docstring_passes "$(cat "$work/run.log")"
write_script code.py 'root = "/opt/searxng-qwen-apu"'
if run; then report python_code_fails accepted; else report python_code_fails ok; fi
git -C "$repo" rm -q --cached remote/code.py; rm -f "$repo/remote/code.py"

printf 'prefix\n/etc\n' >"$repo/runtime/appliance-path-allowlist.tsv"
if run; then report malformed_allowlist_refused accepted; else
    grep -q 'expected prefix and reason' "$work/run.log" && report malformed_allowlist_refused ok || report malformed_allowlist_refused "$(cat "$work/run.log")"
fi

if [ "$failures" -ne 0 ]; then printf '%s failure(s)\n' "$failures"; exit 1; fi
printf 'test-check-appliance-paths: all checks passed\n'
