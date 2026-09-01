#!/bin/sh
set -eu

# A preset section carries LLAMA_ARG_CTX_CHECKPOINTS because common_preset::merge
# would push one router argv value onto every child, so the preset and the
# ledger are two statements of the same count and a bundle carries both. This
# check reads them against each other: every section carries exactly one key,
# a section named for a ledger row carries that row's count, and every other
# section (a draft pair, a web profile, a registry row absent from the ledger)
# carries 0 or a count some ledger row states. A preset generated against
# another ledger therefore fails assembly and activation rather than serving a
# count the bundled ledger never stated. The launch policy still performs the
# full per-section resolution; this is the bundle-level agreement.
#
# usage: verify-bundle-preset-ledger.sh PRESET_INI CTX_LEDGER

if [ "$#" -ne 2 ]; then
    printf 'usage: %s PRESET_INI CTX_LEDGER\n' "$0" >&2
    exit 2
fi
preset_path=$1
ledger_path=$2
for required in "$preset_path" "$ledger_path"; do
    if [ ! -r "$required" ]; then
        printf 'preset ledger check input is unreadable: %s\n' "$required" >&2
        exit 1
    fi
done

awk -F'\t' -v preset="$preset_path" '
    FNR == NR {
        if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/) next
        if (NF < 2 || $2 !~ /^(0|[1-9][0-9]*)$/) {
            printf "ledger row is malformed: %s\n", $0 > "/dev/stderr"
            failed = 1
            next
        }
        ledger[$1] = $2
        stated[$2] = 1
        next
    }
    /^\[/ {
        if (section != "") close_section()
        section = $0
        sub(/^\[/, "", section)
        sub(/\].*$/, "", section)
        sections++
        keys = 0
        next
    }
    /^[[:space:]]*LLAMA_ARG_CTX_CHECKPOINTS[[:space:]]*=/ {
        value = $0
        sub(/^[^=]*=[[:space:]]*/, "", value)
        sub(/[[:space:]]+$/, "", value)
        keys++
        count = value
        next
    }
    function close_section() {
        if (keys != 1) {
            printf "preset section [%s] carries %d LLAMA_ARG_CTX_CHECKPOINTS keys; exactly one is required\n", section, keys > "/dev/stderr"
            failed = 1
            return
        }
        if (count !~ /^(0|[1-9][0-9]*)$/) {
            printf "preset section [%s] carries a malformed checkpoint count: %s\n", section, count > "/dev/stderr"
            failed = 1
            return
        }
        if (section in ledger) {
            if (count + 0 != ledger[section] + 0) {
                printf "preset section [%s] carries checkpoint count %s where the bundled ledger states %s\n", section, count, ledger[section] > "/dev/stderr"
                failed = 1
            }
            return
        }
        if (count + 0 != 0 && !(count in stated)) {
            printf "preset section [%s] carries checkpoint count %s that no bundled ledger row states\n", section, count > "/dev/stderr"
            failed = 1
        }
    }
    END {
        if (section != "") close_section()
        if (sections == 0) {
            printf "preset carries no sections: %s\n", preset > "/dev/stderr"
            failed = 1
        }
        if (failed) exit 1
        printf "preset_ledger_agreement=accepted sections=%d\n", sections
    }
' "$ledger_path" "$preset_path"
