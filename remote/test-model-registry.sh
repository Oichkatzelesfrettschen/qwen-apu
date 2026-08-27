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
            if (NF != 20) {
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
            if ($11 == "required") {
                if ($12 == "-" || system("test -x \"" directory "/" $12 "\"") != 0) {
                    printf "%s: required projector fetch script is not executable: %s\n", $1, $12
                    bad++
                }
            } else if ($12 != "-") {
                printf "%s: projector policy %s carries unexpected fetch script %s\n", $1, $11, $12
                bad++
            }
            if ($17 + 0 < 1 || $18 + 0 < 1) {
                printf "%s: batch %s and ubatch %s must both be positive\n", $1, $17, $18
                bad++
            }
            if ($18 + 0 > $17 + 0) {
                printf "%s: ubatch %s exceeds batch %s\n", $1, $18, $17
                bad++
            }
            # A validated filled depth is a measurement, so it never exceeds the
            # allocation the policy admits, and it never stands without the
            # evidence file that carries the arm it came from.
            if ($19 != "-") {
                if ($19 + 0 > $6 + 0) {
                    printf "%s: validated_filled_depth %s exceeds context_ceiling %s\n", $1, $19, $6
                    bad++
                }
                if ($20 == "-") {
                    printf "%s: validated_filled_depth %s carries no evidence path\n", $1, $19
                    bad++
                }
            }
            if ($20 != "-" && system("test -r \"" directory "/../" $20 "\"") != 0) {
                printf "%s: validation evidence is unreadable: %s\n", $1, $20
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

check_cache_types() {
    cache_type_failures=0
    tab=$(printf '\t')
    while IFS="$tab" read -r model_id _role _model_file _fetch_script \
        _context_default _context_ceiling _context_target cache_type_k \
        cache_type_v _flash_attention _projector _projector_fetch_script \
        _decode_tok_s _prefill_tok_s \
        _quality _tier _batch _ubatch _validated_filled_depth \
        _validation_evidence; do
        case $model_id in
            '' | \#*) continue ;;
        esac
        for cache_type in "$cache_type_k" "$cache_type_v"; do
            if ! "$reader" validate-cache-type "$cache_type"; then
                printf '%s: cache type is outside the runtime vocabulary: %s\n' \
                    "$model_id" "$cache_type" >&2
                cache_type_failures=$((cache_type_failures + 1))
            fi
        done
    done <"$registry"
    [ "$cache_type_failures" -eq 0 ]
}

if check_rows; then
    report registry_rows accepted
else
    report registry_rows rejected
fi
if check_cache_types; then
    report cache_types accepted
else
    report cache_types rejected
fi

if "$reader" validate-cache-type q8_0 &&
   ! "$reader" validate-cache-type q3_k; then
    report cache_type_vocabulary accepted
else
    report cache_type_vocabulary rejected
fi

expected_header=$(printf '# id\trole\tmodel_file\tfetch_script\tcontext_default\tcontext_ceiling\tcontext_target\tcache_type_k\tcache_type_v\tflash_attention\tprojector\tprojector_fetch_script\tdecode_tok_s\tprefill_tok_s\tquality\ttier\tbatch\tubatch\tvalidated_filled_depth\tvalidation_evidence')
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

if [ "$("$reader" id qwen35-2b projector_fetch_script)" = \
    download-qwen35-2b-mmproj.sh ]; then
    report projector_fetch_lookup accepted
else
    report projector_fetch_lookup rejected
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
