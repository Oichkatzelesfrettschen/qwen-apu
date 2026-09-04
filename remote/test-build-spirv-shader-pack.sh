#!/bin/sh
set -eu

# The shader pack builder against a fake compiler, so the record format, the
# content addressing, the refusals, and the unrun-validator reason are checked
# without a toolchain and without a device. The fake glslc writes a module whose
# bytes follow from the defines it was handed, which is what makes two rows that
# differ only in a define land on two digests and two rows that agree land on
# one.

if [ "$#" -gt 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
builder=$script_directory/build-spirv-shader-pack.sh

temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT HUP INT TERM

fake_bin=$temporary_directory/bin
mkdir -p "$fake_bin"
cat >"$fake_bin/glslc" <<'FAKE'
#!/bin/sh
set -eu
if [ "${1:-}" = --version ]; then
    printf 'shaderc v2026.3 fake-pinned\nspirv-tools fake\n'
    exit 0
fi
fake_output=''
fake_defines=''
fake_source=''
while [ "$#" -gt 0 ]; do
    case $1 in
        -o) fake_output=$2; shift 2 ;;
        -D*) fake_defines="$fake_defines ${1#-D}"; shift ;;
        -I) shift 2 ;;
        --target-env=* | -fshader-stage=*) shift ;;
        *) fake_source=$1; shift ;;
    esac
done
# A source naming the refusal is what the refusal arm compiles.
case $fake_source in
    *refused*)
        printf 'fake glslc: the source names no such extension\n' >&2
        exit 1
        ;;
esac
{
    printf 'FAKESPV'
    printf '%s' "$fake_defines"
    cat "$fake_source"
} >"$fake_output"
FAKE
chmod 0755 "$fake_bin/glslc"
cat >"$fake_bin/spirv-val" <<'FAKE'
#!/bin/sh
set -eu
if [ "${1:-}" = --version ]; then
    printf 'SPIRV-Tools v2026.3 fake\n'
    exit 0
fi
for fake_argument in "$@"; do
    case $fake_argument in
        *.spv)
            # A module whose bytes name the invalid define is refused, which is
            # what makes a passing verdict a measurement rather than a default.
            if grep -q INVALID_MODULE "$fake_argument"; then
                printf 'fake spirv-val: invalid module\n' >&2
                exit 1
            fi
            ;;
    esac
done
FAKE
chmod 0755 "$fake_bin/spirv-val"

source_directory=$temporary_directory/shaders
mkdir -p "$source_directory/nested"
printf 'void main() { }\n' >"$source_directory/mul_mat_vecq.comp"
printf 'void main() { /* nested */ }\n' >"$source_directory/nested/other.comp"
printf 'void main() { /* refused */ }\n' >"$source_directory/refused.comp"

declaration=$temporary_directory/pack-declaration.tsv
{
    printf '# module_name\tsource\tdefines\n'
    printf 'q4_k_extension\tmul_mat_vecq.comp\tDATA_A_Q4_K=1,D_TYPE=float\n'
    printf 'q4_k_extension_subgroup\tmul_mat_vecq.comp\tDATA_A_Q4_K=1,D_TYPE=float,USE_SUBGROUP_ADD=1\n'
    printf 'q4_k_extension_again\tmul_mat_vecq.comp\tDATA_A_Q4_K=1,D_TYPE=float\n'
    printf 'nested_module\tnested/other.comp\t-\n'
} >"$declaration"

pack=$temporary_directory/pack
QWEN_SHADER_PACK_GLSLC=$fake_bin/glslc "$builder" \
    "$declaration" "$source_directory" "$pack" >"$temporary_directory/pack.log"
grep -q '^shader_pack=written modules=4 ' "$temporary_directory/pack.log"

pack_ledger=$pack/shader-pack.tsv
[ "$(awk 'END { print NR }' "$pack_ledger")" = 5 ]
[ "$(head -n 1 "$pack_ledger")" = "$(printf 'module_name\tsource\tsource_sha256\tdefines\ttarget_env\tcommand\tspirv_bytes\tspirv_sha256\tvalidation')" ]

read_field() {
    awk -F'\t' -v name="$1" -v column="$2" '$1 == name { print $column }' "$pack_ledger"
}

# Two rows that differ only in a define compile to two modules, and two rows
# that agree compile to one, which is what content addressing states.
first_digest=$(read_field q4_k_extension 8)
repeat_digest=$(read_field q4_k_extension_again 8)
subgroup_digest=$(read_field q4_k_extension_subgroup 8)
[ "$first_digest" = "$repeat_digest" ]
[ "$first_digest" != "$subgroup_digest" ]
[ -f "$pack/modules/$first_digest.spv" ]
[ -f "$pack/modules/$subgroup_digest.spv" ]
[ -L "$pack/modules/q4_k_extension.spv" ]
[ -L "$pack/modules/q4_k_extension_again.spv" ]
[ "$(readlink "$pack/modules/q4_k_extension_again.spv")" = "$first_digest.spv" ]
[ "$(find "$pack/modules" -type f -name '*.spv' | wc -l | tr -d ' ')" = 3 ]

# Every module the validator saw carries its verdict rather than an empty cell.
[ "$(awk -F'\t' 'NR > 1 && $9 == "passed" { count++ } END { print count + 0 }' \
    "$pack_ledger")" = 4 ]
# The digest recorded is the module's own bytes.
[ "$(sha256sum "$pack/modules/$first_digest.spv" | cut -d ' ' -f 1)" = "$first_digest" ]
[ "$(read_field q4_k_extension 7)" = "$(wc -c <"$pack/modules/$first_digest.spv" | tr -d ' ')" ]

# The record states the invocation without carrying a host path: the compiler is
# named `glslc`, the source is relative, and no absolute path appears anywhere.
[ "$(read_field nested_module 2)" = nested/other.comp ]
case $(read_field q4_k_extension 6) in
    'glslc --target-env=vulkan1.2 -fshader-stage=compute -I . -DDATA_A_Q4_K=1 -DD_TYPE=float -o - mul_mat_vecq.comp') ;;
    *)
        printf 'the recorded command is not the declared invocation: %s\n' \
            "$(read_field q4_k_extension 6)" >&2
        exit 1
        ;;
esac
if grep -q "$temporary_directory" "$pack_ledger" "$pack/pack-inputs.tsv"; then
    printf 'the pack record carries a host path\n' >&2
    exit 1
fi
if grep -qE '(^|[^A-Za-z0-9._-])/(home|root|tmp)/' "$pack_ledger" "$pack/pack-inputs.tsv"; then
    printf 'the pack record carries an absolute path\n' >&2
    exit 1
fi

pack_inputs=$pack/pack-inputs.tsv
grep -qxF "$(printf 'schema\tspirv-shader-pack-v1')" "$pack_inputs"
grep -qxF "$(printf 'glslc_version\tshaderc v2026.3 fake-pinned')" "$pack_inputs"
grep -qxF "$(printf 'spirv_val\tSPIRV-Tools v2026.3 fake')" "$pack_inputs"
grep -qxF "$(printf 'target_env\tvulkan1.2')" "$pack_inputs"
grep -qxF "$(printf 'declaration_sha256\t%s' \
    "$(sha256sum "$declaration" | cut -d ' ' -f 1)")" "$pack_inputs"
grep -qxF "$(printf 'pack_sha256\t%s' \
    "$(sha256sum "$pack_ledger" | cut -d ' ' -f 1)")" "$pack_inputs"
grep -qxF "$(printf 'glslc_sha256\t%s' \
    "$(sha256sum "$fake_bin/glslc" | cut -d ' ' -f 1)")" "$pack_inputs"
printf 'pack_record=accepted\n'

# An absent validator leaves the reason rather than an empty verdict, because a
# blank cell beside three passes reads as a pass.
unvalidated_pack=$temporary_directory/pack-unvalidated
QWEN_SHADER_PACK_GLSLC=$fake_bin/glslc \
    QWEN_SHADER_PACK_SPIRV_VAL=$temporary_directory/absent-validator \
    "$builder" "$declaration" "$source_directory" "$unvalidated_pack" \
    >"$temporary_directory/unvalidated.log"
grep -q 'validation=not_run:validator_absent$' "$temporary_directory/unvalidated.log"
[ "$(awk -F'\t' 'NR > 1 && $9 == "not_run:validator_absent" { count++ } END { print count + 0 }' \
    "$unvalidated_pack/shader-pack.tsv")" = 4 ]
grep -qxF "$(printf 'spirv_val\tabsent')" "$unvalidated_pack/pack-inputs.tsv"
grep -qxF "$(printf 'spirv_val_sha256\t-')" "$unvalidated_pack/pack-inputs.tsv"
printf 'validator_absent=accepted\n'

# A module the validator refuses ends the pack rather than being recorded as a
# module a consumer may load.
invalid_declaration=$temporary_directory/invalid-declaration.tsv
printf 'invalid_module\tmul_mat_vecq.comp\tINVALID_MODULE=1\n' >"$invalid_declaration"
invalid_status=0
QWEN_SHADER_PACK_GLSLC=$fake_bin/glslc "$builder" \
    "$invalid_declaration" "$source_directory" "$temporary_directory/pack-invalid" \
    >/dev/null 2>"$temporary_directory/invalid.log" || invalid_status=$?
[ "$invalid_status" -eq 1 ]
grep -q 'spirv-val refused invalid_module' "$temporary_directory/invalid.log"
printf 'validator_refusal=accepted\n'

# A compiler refusal ends the pack the same way.
refused_declaration=$temporary_directory/refused-declaration.tsv
printf 'refused_module\trefused.comp\t-\n' >"$refused_declaration"
refused_status=0
QWEN_SHADER_PACK_GLSLC=$fake_bin/glslc "$builder" \
    "$refused_declaration" "$source_directory" "$temporary_directory/pack-refused" \
    >/dev/null 2>"$temporary_directory/refused.log" || refused_status=$?
[ "$refused_status" -eq 1 ]
grep -q 'the pinned compiler refused refused_module' "$temporary_directory/refused.log"
printf 'compiler_refusal=accepted\n'

# The refusals that keep a pack from naming something it did not compile.
run_refusal() {
    refusal_name=$1
    refusal_expected_status=$2
    refusal_message=$3
    shift 3
    refusal_status=0
    QWEN_SHADER_PACK_GLSLC=$fake_bin/glslc "$builder" "$@" \
        >/dev/null 2>"$temporary_directory/$refusal_name.log" || refusal_status=$?
    if [ "$refusal_status" -ne "$refusal_expected_status" ]; then
        printf '%s exited %s where %s was expected\n' \
            "$refusal_name" "$refusal_status" "$refusal_expected_status" >&2
        cat "$temporary_directory/$refusal_name.log" >&2
        exit 1
    fi
    grep -q "$refusal_message" "$temporary_directory/$refusal_name.log"
    printf '%s=accepted\n' "$refusal_name"
}

escaping_declaration=$temporary_directory/escaping-declaration.tsv
printf 'escaping\t../outside.comp\t-\n' >"$escaping_declaration"
run_refusal source_escapes_root 1 'a declared source is a relative path inside the source directory' \
    "$escaping_declaration" "$source_directory" "$temporary_directory/pack-escaping"

malformed_declaration=$temporary_directory/malformed-declaration.tsv
printf 'bad name\tmul_mat_vecq.comp\t-\n' >"$malformed_declaration"
run_refusal module_name_shape 1 'a module name is alphanumeric with underscore and hyphen' \
    "$malformed_declaration" "$source_directory" "$temporary_directory/pack-malformed"

bad_define_declaration=$temporary_directory/bad-define-declaration.tsv
printf 'bad_define\tmul_mat_vecq.comp\t1BAD=1\n' >"$bad_define_declaration"
run_refusal define_shape 1 'a declared define is NAME=VALUE' \
    "$bad_define_declaration" "$source_directory" "$temporary_directory/pack-bad-define"

empty_declaration=$temporary_directory/empty-declaration.tsv
printf '# module_name\tsource\tdefines\n' >"$empty_declaration"
run_refusal empty_declaration 1 'the pack declaration names no module' \
    "$empty_declaration" "$source_directory" "$temporary_directory/pack-empty"

run_refusal output_directory_exists 1 'the output directory already exists' \
    "$declaration" "$source_directory" "$pack"

target_env_status=0
QWEN_SHADER_PACK_GLSLC=$fake_bin/glslc QWEN_SHADER_PACK_TARGET_ENV=opengl "$builder" \
    "$declaration" "$source_directory" "$temporary_directory/pack-target-env" \
    >/dev/null 2>"$temporary_directory/target-env.log" || target_env_status=$?
[ "$target_env_status" -eq 2 ]
grep -q 'the target environment is vulkan1.0 through vulkan1.3' \
    "$temporary_directory/target-env.log"
printf 'target_env_shape=accepted\n'

missing_glslc_status=0
QWEN_SHADER_PACK_GLSLC=$temporary_directory/absent-glslc "$builder" \
    "$declaration" "$source_directory" "$temporary_directory/pack-no-glslc" \
    >/dev/null 2>"$temporary_directory/no-glslc.log" || missing_glslc_status=$?
[ "$missing_glslc_status" -eq 1 ]
grep -q 'the pinned glslc is missing or not executable' "$temporary_directory/no-glslc.log"
printf 'pinned_compiler_required=accepted\n'

argument_status=0
"$builder" >/dev/null 2>&1 || argument_status=$?
[ "$argument_status" -eq 2 ]
printf 'usage=accepted\n'

printf 'build_spirv_shader_pack=accepted\n'
