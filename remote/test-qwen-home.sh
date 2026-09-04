#!/bin/sh
# The runtime root resolver: repo-local by default, moved by QWEN_HOME, one
# value per name from the sourced form and the command form alike.
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
resolver=$script_directory/qwen-home.sh
tree_root=$(CDPATH='' cd -- "$script_directory/.." && pwd -P)
failures=0
report() {
    if [ "$2" = ok ]; then printf 'ok %s\n' "$1"; else printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); fi
}

# ---- the default is .runtime beside remote/, never a home-directory sibling ----
default_home=$(env -u QWEN_HOME "$resolver" print qwen_home)
[ "$default_home" = "$tree_root/.runtime" ] && report default_is_repo_local ok || report default_is_repo_local "$default_home"
case $default_home in
    "${HOME:?}"/qwen-* | "$HOME"/.runtime) report default_is_not_a_home_sibling "$default_home" ;;  # appliance-path: named
    *) report default_is_not_a_home_sibling ok ;;
esac

# ---- every declared path sits under the root ----
paths_under_root=ok
env -u QWEN_HOME "$resolver" paths | while IFS="$(printf '\t')" read -r name value; do
    case $name in
        qwen_tree_root) [ "$value" = "$tree_root" ] || { printf 'tree root %s\n' "$value"; exit 1; } ;;
        *) case $value in "$tree_root/.runtime"*) ;; *) printf '%s outside the root: %s\n' "$name" "$value"; exit 1 ;; esac ;;
    esac
done || paths_under_root=failed
report every_path_under_root "$paths_under_root"

# ---- QWEN_HOME moves the whole layout ----
moved=$(QWEN_HOME=/mnt/elsewhere "$resolver" print qwen_home_models qwen_home_searxng_python qwen_home_web_token_key | tr '\n' ' ')
[ "$moved" = '/mnt/elsewhere/models /mnt/elsewhere/opt/searxng/venv/bin/python /mnt/elsewhere/state/web-token.key ' ] \
    && report override_moves_every_path ok || report override_moves_every_path "$moved"

# ---- a relative QWEN_HOME is refused ----
if QWEN_HOME=relative/root "$resolver" print qwen_home >/dev/null 2>&1; then
    report relative_home_refused accepted
else
    report relative_home_refused ok
fi

# ---- an unknown name is refused ----
if "$resolver" print qwen_home_nothing >/dev/null 2>&1; then report unknown_name_refused accepted; else report unknown_name_refused ok; fi

# ---- the sourced form sets the same values and exports QWEN_HOME alone ----
sourced=$(env -u QWEN_HOME sh -c '
    set -eu
    script_directory=$1
    . "$script_directory/qwen-home.sh"
    printf "%s %s %s\n" "$qwen_home_state" "${QWEN_HOME:-unset}" "${QWEN_WEBUI_STATE_DIRECTORY:-unset}"
' sh "$script_directory")
[ "$sourced" = "$tree_root/.runtime/state $tree_root/.runtime unset" ] \
    && report sourced_form_matches_command_form ok || report sourced_form_matches_command_form "$sourced"

# ---- the python module agrees ----
python_home=$(env -u QWEN_HOME python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import qwen_home; print(qwen_home.home()); print(qwen_home.path("searxng_python"))' "$script_directory" | tr '\n' ' ')
[ "$python_home" = "$tree_root/.runtime $tree_root/.runtime/opt/searxng/venv/bin/python " ] \
    && report python_module_agrees ok || report python_module_agrees "$python_home"

if [ "$failures" -ne 0 ]; then printf '%s failure(s)\n' "$failures"; exit 1; fi
printf 'test-qwen-home: all checks passed\n'
