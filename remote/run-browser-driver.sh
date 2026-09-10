#!/bin/sh
# Run a browser acquisition through the Python environment owned by QWEN_HOME.

set -eu

usage() {
    printf 'usage: %s --driver FILE --firefox-bin FILE --record-directory DIR [--preflight-only] [-- DRIVER_ARG...]\n' "$0" >&2
    exit 2
}

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
. "$script_directory/qwen-home.sh"
qwen_home_require_binding

[ "$#" -ge 6 ] || usage
# shellcheck disable=SC2154  # qwen-home.sh assigns every qwen_home_* location
browser_python=$qwen_home_browser_python
[ -x "$browser_python" ] || {
    printf 'the declared browser Python is unavailable: %s\n' "$browser_python" >&2
    exit 2
}

QWEN_BROWSER_RUNTIME_ROOT=$QWEN_HOME
export QWEN_BROWSER_RUNTIME_ROOT
exec "$browser_python" -I "$script_directory/browser-driver-preflight.py" \
    --expected-python "$browser_python" "$@"
