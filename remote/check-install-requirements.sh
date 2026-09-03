#!/bin/sh
set -eu

# Read docs/install-requirements.tsv and prove each requirement present on the
# host named on the command line. The ledger states what a module needs and the
# check command states how that presence is observed, so a reader installs from
# one authority and the machine answers from the same one.
#
# The host is an argument rather than a hostname lookup, because a hostname
# branch would put a private name in a committed script and because the same
# tree is read on the appliance, on the workstation helper, and inside a
# container that carries neither name.
#
# `validate` runs the shape rules alone. Row shape is a property of the row and
# the existence of the file a row cites is a property of the tree, so both
# belong where the tree is; the checks themselves belong on the host that
# carries the software, which is the boundary `check-ledger-evidence.sh` draws
# for the three runtime ledgers.

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    printf 'usage: %s laptop|workstation|validate [REQUIREMENT_TSV]\n' "$0" >&2
    exit 2
fi

requested_mode=$1
case $requested_mode in
    laptop | workstation | validate) ;;
    *)
        printf 'usage: %s laptop|workstation|validate [REQUIREMENT_TSV]\n' "$0" >&2
        exit 2
        ;;
esac

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH='' cd -- "$script_directory/.." && pwd -P)
requirement_ledger=${2:-$repository_root/docs/install-requirements.tsv}

if [ ! -r "$requirement_ledger" ]; then
    printf 'requirement ledger is unreadable: %s\n' "$requirement_ledger" >&2
    exit 2
fi

expected_header='module	host	kind	name	version_pin	check_command	source_ref'
IFS= read -r observed_header <"$requirement_ledger" || observed_header=''
if [ "$observed_header" != "$expected_header" ]; then
    printf 'requirement ledger header is not the seven declared columns: %s\n' \
        "$requirement_ledger" >&2
    exit 2
fi

field_separator=$(printf '\t')
rejections=0
present_count=0
absent_count=0
optional_absent_count=0
skipped_count=0
not_run_count=0
row_number=1

# AWK drops the header, blank lines, and comments and asserts the column count,
# so the shell loop reads seven fields per line and a malformed row is named
# with its own line number rather than shifting a later field into the check
# command.
ledger_rows=$(awk -F'\t' '
    NR == 1 { next }
    /^[[:space:]]*($|#)/ { next }
    NF != 7 {
        printf "row %d carries %d columns rather than 7\n", NR, NF > "/dev/stderr"
        malformed = 1
        next
    }
    { print }
    END { if (malformed) exit 1 }
' "$requirement_ledger") || {
    printf 'install_requirements=rejected reason=column_count\n' >&2
    exit 1
}

# Each source_ref element is `path` or `path:LINE`; the line number rots as the
# tree moves and the path is what the gate can still prove. A leading slash or
# a `..` component names a file outside the tree, which is a claim this
# repository cannot check, so the shape rule refuses it.
validate_source_refs() {
    reference_list=$1
    reference_module=$2
    reference_name=$3
    remaining_references=$reference_list
    while [ -n "$remaining_references" ]; do
        case $remaining_references in
            *,*)
                one_reference=${remaining_references%%,*}
                remaining_references=${remaining_references#*,}
                ;;
            *)
                one_reference=$remaining_references
                remaining_references=''
                ;;
        esac
        reference_path=$one_reference
        reference_line=${one_reference##*:}
        case $one_reference in
            *:*)
                case $reference_line in
                    '' | *[!0-9]*) ;;
                    *) reference_path=${one_reference%:*} ;;
                esac
                ;;
        esac
        case $reference_path in
            '' | /* | .. | ../* | */../* | */..)
                printf '%s %s names a source outside the tree: %s\n' \
                    "$reference_module" "$reference_name" "$one_reference" >&2
                rejections=$((rejections + 1))
                continue
                ;;
        esac
        if [ ! -e "$repository_root/$reference_path" ]; then
            printf '%s %s names a source absent from the tree: %s\n' \
                "$reference_module" "$reference_name" "$one_reference" >&2
            rejections=$((rejections + 1))
        fi
    done
}

while IFS=$field_separator read -r row_module row_host row_kind row_name \
    row_version_pin row_check_command row_source_ref; do
    [ -n "$row_module" ] || continue
    row_number=$((row_number + 1))

    case $row_module in
        '' | *[!a-z0-9-]*)
            printf 'row %s carries a module outside [a-z0-9-]: %s\n' \
                "$row_number" "$row_module" >&2
            rejections=$((rejections + 1))
            continue
            ;;
    esac
    case $row_host in
        laptop | workstation | both) ;;
        *)
            printf '%s %s carries an unknown host: %s\n' \
                "$row_module" "$row_name" "$row_host" >&2
            rejections=$((rejections + 1))
            continue
            ;;
    esac
    case $row_kind in
        command | python-module | node-package | package | env | path | sysfs) ;;
        optional-command | optional-env | optional-path | manual) ;;
        *)
            printf '%s %s carries an unknown kind: %s\n' \
                "$row_module" "$row_name" "$row_kind" >&2
            rejections=$((rejections + 1))
            continue
            ;;
    esac
    if [ -z "$row_name" ] || [ -z "$row_version_pin" ] ||
        [ -z "$row_check_command" ] || [ -z "$row_source_ref" ]; then
        printf '%s row %s leaves a declared column empty\n' \
            "$row_module" "$row_number" >&2
        rejections=$((rejections + 1))
        continue
    fi
    validate_source_refs "$row_source_ref" "$row_module" "$row_name"

    [ "$requested_mode" = validate ] && continue

    if [ "$row_host" != both ] && [ "$row_host" != "$requested_mode" ]; then
        skipped_count=$((skipped_count + 1))
        printf 'requirement module=%s kind=%s name=%s result=skipped host=%s\n' \
            "$row_module" "$row_kind" "$row_name" "$row_host"
        continue
    fi

    # A `manual` row states a requirement whose observation needs privilege or
    # a device transition this checker declines to make, so it reports `not-run`
    # with the reason in docs/INSTALL.md rather than a check that passes by
    # measuring something else.
    if [ "$row_kind" = manual ]; then
        not_run_count=$((not_run_count + 1))
        printf 'requirement module=%s kind=%s name=%s result=not-run\n' \
            "$row_module" "$row_kind" "$row_name"
        continue
    fi

    # The check runs through `sh -c` because a row states a pipeline as often as
    # a single command, and the ledger text stays one argument rather than
    # becoming this script's own words.
    if sh -c "$row_check_command" >/dev/null 2>&1; then
        present_count=$((present_count + 1))
        printf 'requirement module=%s kind=%s name=%s result=present version_pin=%s\n' \
            "$row_module" "$row_kind" "$row_name" "$row_version_pin"
        continue
    fi
    case $row_kind in
        optional-*)
            optional_absent_count=$((optional_absent_count + 1))
            printf 'requirement module=%s kind=%s name=%s result=optional-absent\n' \
                "$row_module" "$row_kind" "$row_name"
            ;;
        *)
            absent_count=$((absent_count + 1))
            printf 'requirement module=%s kind=%s name=%s result=absent\n' \
                "$row_module" "$row_kind" "$row_name"
            ;;
    esac
done <<EOF
$ledger_rows
EOF

if [ "$requested_mode" = validate ]; then
    if [ "$rejections" -eq 0 ]; then
        printf 'install_requirements=accepted mode=validate rows=%s\n' \
            "$((row_number - 1))"
        exit 0
    fi
    printf 'install_requirements=rejected mode=validate failures=%s\n' \
        "$rejections" >&2
    exit 1
fi

if [ "$rejections" -eq 0 ] && [ "$absent_count" -eq 0 ]; then
    printf 'install_requirements=accepted host=%s present=%s optional_absent=%s skipped=%s not_run=%s\n' \
        "$requested_mode" "$present_count" "$optional_absent_count" \
        "$skipped_count" "$not_run_count"
    exit 0
fi
printf 'install_requirements=rejected host=%s absent=%s malformed=%s present=%s\n' \
    "$requested_mode" "$absent_count" "$rejections" "$present_count" >&2
exit 1
