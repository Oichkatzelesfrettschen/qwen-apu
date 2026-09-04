#!/bin/sh
set -eu

# Compile a declared set of GLSL modules into a content-addressed SPIR-V pack,
# so a device that cannot produce a module can still execute one whose origin is
# stated. The appliance's distribution shaderc rejects
# GL_EXT_integer_dot_product, which closes E5-S0 and E5-S1 at the producer
# rather than at the driver; a pack built by the pinned compiler
# fetch-shaderc-toolchain.sh installs is what carries those modules across.
#
# The declaration is data rather than argv, because the record has to state the
# exact command line a module was produced by and a list assembled in shell
# would state the shell instead. Each row is module_name, source path relative
# to the source directory, and a comma-separated define list or `-`.
#
# The record keeps no absolute path: the compiler is named by its own version
# string and digest, every source is named relative to the source directory, and
# the recorded command line names the compiler as `glslc`. A pack is therefore
# comparable between hosts and commits clean.
#
# spirv-val is the module's own admission. Where it is absent the pack records
# `not_run` with the reason rather than an empty verdict, because an unrun check
# that reads as a pass is the failure mode this column exists to remove.
#
# usage: build-spirv-shader-pack.sh DECLARATION SOURCE_DIRECTORY OUTPUT_DIRECTORY
#   QWEN_SHADER_PACK_GLSLC       the pinned glslc, default the compiler
#                                fetch-shaderc-toolchain.sh installs: the
#                                `prefix` row of shaderc-toolchain.tsv under
#                                QWEN_SHADERC_PREFIX_ROOT, ~/opt by default.
#                                Both scripts read the one ledger row, so the
#                                fetch and the pack cannot name two prefixes.
#   QWEN_SHADERC_LEDGER          that ledger, default beside this script
#   QWEN_SHADER_PACK_SPIRV_VAL   spirv-val, default beside that glslc
#   QWEN_SHADER_PACK_TARGET_ENV  --target-env value, default vulkan1.2
#   QWEN_SHADER_PACK_OPTIMIZE    1 adds -O, default 0
#
# The optimization setting belongs to the pack rather than to a row, the way the
# target environment does, and it changes the module: `vulkan-shaders-gen`
# compiles every ggml shader with `-O`, so a pack meant to reproduce a module a
# served build executed sets it and a pack meant to read the unoptimized form
# leaves it off. pack-inputs.tsv records which, and the recorded command line
# carries the flag.

if [ "$#" -ne 3 ]; then
    printf 'usage: %s DECLARATION SOURCE_DIRECTORY OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi

declaration=$1
source_directory=$2
output_directory=$3

if [ ! -r "$declaration" ]; then
    printf 'the pack declaration is unreadable: %s\n' "$declaration" >&2
    exit 1
fi
if [ ! -d "$source_directory" ]; then
    printf 'the shader source directory is missing: %s\n' "$source_directory" >&2
    exit 1
fi
if [ -e "$output_directory" ]; then
    printf 'the output directory already exists, so a pack would be written over one a receipt may name: %s\n' \
        "$output_directory" >&2
    exit 1
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"
glslc_program=${QWEN_SHADER_PACK_GLSLC:-}
if [ -z "$glslc_program" ]; then
    toolchain_ledger=${QWEN_SHADERC_LEDGER:-$script_directory/shaderc-toolchain.tsv}
    if [ ! -r "$toolchain_ledger" ]; then
        printf 'the shaderc toolchain ledger is unreadable, so no default compiler resolves: %s\n' \
            "$toolchain_ledger" >&2
        printf 'QWEN_SHADER_PACK_GLSLC names the compiler directly\n' >&2
        exit 1
    fi
    # The row shape is checked here the way fetch-shaderc-toolchain.sh checks
    # it, so one ledger reads the same to both of its readers.
    toolchain_prefix_name=$(awk -F'\t' '
        /^#/ || NF == 0 { next }
        NF != 2 { printf "malformed shaderc toolchain row: %s\n", $0 > "/dev/stderr"; exit 1 }
        $1 == "prefix" { print $2; found = 1 }
        END { exit found ? 0 : 1 }
    ' "$toolchain_ledger") || {
        printf 'the shaderc toolchain ledger names no prefix: %s\n' \
            "$toolchain_ledger" >&2
        exit 1
    }
    glslc_program=${QWEN_SHADERC_PREFIX_ROOT:-"$qwen_home_shaderc_root"}/$toolchain_prefix_name/bin/glslc
fi
if [ ! -x "$glslc_program" ]; then
    printf 'the pinned glslc is missing or not executable: %s\n' "$glslc_program" >&2
    printf 'remote/fetch-shaderc-toolchain.sh installs it into a prefix of its own\n' >&2
    exit 1
fi
glslc_directory=$(CDPATH='' cd -- "$(dirname -- "$glslc_program")" && pwd)
spirv_val_program=${QWEN_SHADER_PACK_SPIRV_VAL:-$glslc_directory/spirv-val}
target_env=${QWEN_SHADER_PACK_TARGET_ENV:-vulkan1.2}
case $target_env in
    vulkan1.[0-3]) ;;
    *)
        printf 'the target environment is vulkan1.0 through vulkan1.3: %s\n' \
            "$target_env" >&2
        exit 2
        ;;
esac
optimize_setting=${QWEN_SHADER_PACK_OPTIMIZE:-0}
optimize_arguments=''
case $optimize_setting in
    0) ;;
    1) optimize_arguments=' -O' ;;
    *)
        printf 'the optimization setting is 0 or 1: %s\n' "$optimize_setting" >&2
        exit 2
        ;;
esac

glslc_version=$("$glslc_program" --version | head -n 1)
case $glslc_version in
    *[!\ -~]* | '')
        printf 'the compiler printed no single-line printable version\n' >&2
        exit 1
        ;;
esac
glslc_sha256=$(sha256sum "$glslc_program" | cut -d ' ' -f 1)
declaration_sha256=$(sha256sum "$declaration" | cut -d ' ' -f 1)

spirv_val_identity=absent
spirv_val_sha256=-
if [ -x "$spirv_val_program" ]; then
    spirv_val_identity=$("$spirv_val_program" --version 2>&1 | head -n 1)
    spirv_val_sha256=$(sha256sum "$spirv_val_program" | cut -d ' ' -f 1)
fi

source_root=$(CDPATH='' cd -- "$source_directory" && pwd)
mkdir -p "$output_directory/modules"
pack_ledger=$output_directory/shader-pack.tsv
pack_inputs=$output_directory/pack-inputs.tsv
printf 'module_name\tsource\tsource_sha256\tdefines\ttarget_env\tcommand\tspirv_bytes\tspirv_sha256\tvalidation\n' \
    >"$pack_ledger"

declared_rows=0
while IFS='	' read -r module_name module_source module_defines module_excess; do
    case $module_name in
        '#'* | '') continue ;;
    esac
    if [ -z "$module_defines" ] || [ -n "$module_excess" ]; then
        printf 'a declaration row is module_name, source, and defines: %s\n' \
            "$module_name" >&2
        exit 1
    fi
    case $module_name in
        *[!A-Za-z0-9_-]*)
            printf 'a module name is alphanumeric with underscore and hyphen: %s\n' \
                "$module_name" >&2
            exit 1
            ;;
    esac
    # A source outside the declared root would put a path the record cannot
    # state relative into the pack, so the row names one relative path and the
    # traversal is refused rather than normalized.
    case $module_source in
        /* | *..*)
            printf 'a declared source is a relative path inside the source directory: %s\n' \
                "$module_source" >&2
            exit 1
            ;;
    esac
    if [ ! -r "$source_root/$module_source" ]; then
        printf 'a declared source is unreadable: %s\n' "$module_source" >&2
        exit 1
    fi
    declared_rows=$((declared_rows + 1))

    define_arguments=''
    recorded_defines=$module_defines
    if [ "$module_defines" != - ]; then
        saved_ifs=$IFS
        IFS=','
        for define_entry in $module_defines; do
            case $define_entry in
                [A-Za-z_]*=*) ;;
                *)
                    IFS=$saved_ifs
                    printf 'a declared define is NAME=VALUE: %s\n' "$define_entry" >&2
                    exit 1
                    ;;
            esac
            define_arguments="$define_arguments -D$define_entry"
        done
        IFS=$saved_ifs
    fi

    module_object=$output_directory/modules/$module_name.spv
    # The recorded command names the compiler as `glslc` and the source
    # relative to the declared root, so the record states the invocation
    # without carrying this host's own paths.
    recorded_command="glslc --target-env=$target_env -fshader-stage=compute$optimize_arguments -I .$define_arguments -o - $module_source"
    # shellcheck disable=SC2086
    if ! "$glslc_program" --target-env="$target_env" -fshader-stage=compute \
        $optimize_arguments -I "$source_root" $define_arguments \
        -o "$module_object" "$source_root/$module_source" \
        >"$output_directory/modules/$module_name.log" 2>&1; then
        printf 'the pinned compiler refused %s\n' "$module_name" >&2
        cat "$output_directory/modules/$module_name.log" >&2
        exit 1
    fi
    rm -f -- "$output_directory/modules/$module_name.log"

    module_sha256=$(sha256sum "$module_object" | cut -d ' ' -f 1)
    module_bytes=$(wc -c <"$module_object" | tr -d ' ')
    # Content addressing is the pack's own identity rule: the module lands under
    # its digest and the named copy is a link to it, so two declarations that
    # compile to one module store one file and a consumer resolves either name.
    addressed_object=$output_directory/modules/$module_sha256.spv
    if [ ! -e "$addressed_object" ]; then
        mv -- "$module_object" "$addressed_object"
    else
        rm -f -- "$module_object"
    fi
    ln -s -- "$module_sha256.spv" "$module_object"

    module_validation=not_run:validator_absent
    if [ "$spirv_val_identity" != absent ]; then
        if "$spirv_val_program" --target-env "$target_env" "$addressed_object" \
            >"$output_directory/modules/$module_name.val" 2>&1; then
            module_validation=passed
        else
            module_validation=failed
            printf 'spirv-val refused %s\n' "$module_name" >&2
            cat "$output_directory/modules/$module_name.val" >&2
            exit 1
        fi
        rm -f -- "$output_directory/modules/$module_name.val"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$module_name" "$module_source" \
        "$(sha256sum "$source_root/$module_source" | cut -d ' ' -f 1)" \
        "$recorded_defines" "$target_env" "$recorded_command" \
        "$module_bytes" "$module_sha256" "$module_validation" \
        >>"$pack_ledger"
done <"$declaration"

if [ "$declared_rows" -eq 0 ]; then
    printf 'the pack declaration names no module: %s\n' "$declaration" >&2
    exit 1
fi

pack_sha256=$(sha256sum "$pack_ledger" | cut -d ' ' -f 1)
{
    printf 'key\tvalue\n'
    printf 'schema\tspirv-shader-pack-v1\n'
    printf 'declaration_sha256\t%s\n' "$declaration_sha256"
    printf 'glslc_version\t%s\n' "$glslc_version"
    printf 'glslc_sha256\t%s\n' "$glslc_sha256"
    printf 'spirv_val\t%s\n' "$spirv_val_identity"
    printf 'spirv_val_sha256\t%s\n' "$spirv_val_sha256"
    printf 'target_env\t%s\n' "$target_env"
    printf 'optimize\t%s\n' "$optimize_setting"
    printf 'modules\t%s\n' "$declared_rows"
    printf 'pack_sha256\t%s\n' "$pack_sha256"
} >"$pack_inputs"

printf 'shader_pack=written modules=%s pack_sha256=%s glslc=%s validation=%s\n' \
    "$declared_rows" "$pack_sha256" "$glslc_version" \
    "$(awk -F'\t' 'NR > 1 { print $9 }' "$pack_ledger" | sort -u | paste -sd,)"
