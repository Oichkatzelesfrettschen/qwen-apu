#!/bin/sh
set -eu

# The registry decides which fetch script runs and how deep a context the
# policy admits, so a malformed row reaches the appliance as a failed launch or
# an admitted allocation the machine cannot hold. These checks read every row.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
registry=$script_directory/models.tsv
reader=$script_directory/model-registry.sh
failures=0

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

check_rows() {
    awk -F'\t' -v directory="$script_directory" '
        /^#/ { next }
        /^[[:space:]]*$/ { next }
        {
            rows++
            if (NF != 14) {
                printf "row %d holds %d fields\n", NR, NF
                bad++
                next
            }
            if (seen[$1]++) { printf "duplicate id %s\n", $1; bad++ }
            if ($5 + 0 > $6 + 0) {
                printf "%s: context_default %s exceeds context_ceiling %s\n", $1, $5, $6
                bad++
            }
            if ($6 + 0 > $7 + 0) {
                printf "%s: context_ceiling %s exceeds context_target %s\n", $1, $6, $7
                bad++
            }
            if ($10 != "on" && $10 != "off" && $10 != "auto") {
                printf "%s: flash_attention %s is not on, off, or auto\n", $1, $10
                bad++
            }
            if ($11 != "none" && $11 != "required" && $11 != "optional") {
                printf "%s: projector policy %s is not none, required, or optional\n", $1, $11
                bad++
            }
            script = directory "/" $4
            if (system("test -x \"" script "\"") != 0) {
                printf "%s: fetch script is not executable: %s\n", $1, $4
                bad++
            }
        }
        END {
            if (!rows) { print "registry holds no rows"; bad++ }
            exit bad ? 1 : 0
        }
    ' "$registry"
}

if check_rows; then
    report registry_rows accepted
else
    report registry_rows rejected
fi

expected_header=$(printf '# id\trole\tmodel_file\tfetch_script\tcontext_default\tcontext_ceiling\tcontext_target\tcache_type_k\tcache_type_v\tflash_attention\tprojector\tdecode_tok_s\tprefill_tok_s\tquality')
actual_header=$(grep '^# id' "$registry" || true)
if [ "$actual_header" = "$expected_header" ]; then
    report schema_header accepted
else
    report schema_header rejected
    printf 'registry schema header differs from the reader schema\n' >&2
fi

if [ "$("$reader" id qwen38-4b-distill role)" = balanced-text ]; then
    report id_lookup accepted
else
    report id_lookup rejected
fi

resolved=$("$reader" path \
    /any/prefix/Qwen3.8-2B-Distill-GGUF/Qwen3.8-2B-Q4_K_M.gguf context_ceiling)
if [ "$resolved" = 32768 ]; then
    report path_lookup accepted
else
    report path_lookup rejected
fi

# A row that does not exist must fail rather than print an empty field, because
# the launch path treats an empty fetch script as "no pinned source" and the
# policy treats an empty ceiling as the conservative default.
set +e
"$reader" id no-such-model >/dev/null 2>&1
absent_status=$?
"$reader" id qwen38-4b-distill no-such-field >/dev/null 2>&1
field_status=$?
"$reader" >/dev/null 2>&1
usage_status=$?
set -e

if [ "$absent_status" -eq 1 ]; then
    report absent_row accepted
else
    report absent_row rejected
fi
if [ "$field_status" -eq 3 ]; then
    report absent_field accepted
else
    report absent_field rejected
fi
if [ "$usage_status" -eq 2 ]; then
    report usage_exit accepted
else
    report usage_exit rejected
fi

if [ "$failures" -eq 0 ]; then
    printf 'model_registry=accepted\n'
    exit 0
fi
printf 'model_registry=rejected failures=%s\n' "$failures" >&2
exit 1
