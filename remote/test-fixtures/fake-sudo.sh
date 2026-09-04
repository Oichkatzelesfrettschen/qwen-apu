#!/bin/sh
set -eu

# A reusable fake `sudo -n`, standing for the credential rather than for the
# privilege: it answers `-n true` from its own control file and otherwise runs
# the command it was handed, so an absent-credential refusal and the ordinary
# path differ in that one answer.
#
# QWEN_FAKE_SUDO_CONTROLS names a tab-separated `key value` file. A row
# `refuse_credential 1` makes every invocation fail the way sudo fails an
# expired timestamp; its absence, or any other value, honors the invocation.

controls=${QWEN_FAKE_SUDO_CONTROLS:?QWEN_FAKE_SUDO_CONTROLS is required}

control() {
    [ -r "$controls" ] || return 0
    LC_ALL=C awk -F'\t' -v key="$1" '$1 == key { value = $2 } END { print value }' \
        "$controls"
}

if [ "$(control refuse_credential)" = 1 ]; then
    printf 'sudo: a password is required\n' >&2
    exit 1
fi

if [ "${1:-}" = -n ]; then
    shift
fi
if [ "${1:-}" = true ] && [ "$#" -eq 1 ]; then
    exit 0
fi
exec "$@"
