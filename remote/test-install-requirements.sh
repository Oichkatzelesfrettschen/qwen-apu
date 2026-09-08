#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
checker=$script_directory/check-install-requirements.sh
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/install-requirements.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
ledger=$temporary_directory/requirements.tsv

write_ledger() {
    printf '%b\n' \
        'module\thost\tkind\tname\tversion_pin\tcheck_command\tsource_ref' \
        'runtime-root\tlaptop\tcommand\truntime command\t-\ttrue\tAGENTS.md' \
        'launch-chain\tlaptop\tcommand\tlaunch command\t-\ttrue\tAGENTS.md' \
        'repository-gate\tlaptop\tcommand\tdeveloper tool\t-\tfalse\tAGENTS.md' \
        >"$ledger"
}
write_ledger

if "$checker" laptop "$ledger" >/dev/null 2>&1; then
    printf 'full inventory accepted an absent developer tool\n' >&2
    exit 1
fi
"$checker" laptop "$ledger" runtime-root,launch-chain >/dev/null

sed 's/runtime command/actual missing runtime dependency/; s/\ttrue\tAGENTS.md$/\tfalse\tAGENTS.md/' \
    "$ledger" >"$temporary_directory/missing.tsv"
if "$checker" laptop "$temporary_directory/missing.tsv" runtime-root,launch-chain >/dev/null 2>&1; then
    printf 'runtime subset accepted a missing runtime dependency\n' >&2
    exit 1
fi

for selector in definitely-unknown 'runtime-root,' ',launch-chain' 'runtime-root,,launch-chain'; do
    if "$checker" laptop "$ledger" "$selector" >/dev/null 2>&1; then
        printf 'invalid selector accepted: %s\n' "$selector" >&2
        exit 1
    fi
done

printf '%b\n' \
    'module\thost\tkind\tname\tversion_pin\tcheck_command\tsource_ref' \
    'runtime-root\tlaptop\tcommand\truntime command\t-\ttrue\tAGENTS.md' \
    'launch-chain\tlaptop\tcommand\tbroken row' \
    >"$temporary_directory/malformed.tsv"
if "$checker" laptop "$temporary_directory/malformed.tsv" runtime-root >/dev/null 2>&1; then
    printf 'unselected malformed row was accepted\n' >&2
    exit 1
fi

printf 'install requirements selector fixture: full, scoped, refusal, and ledger validation paths passed\n'
