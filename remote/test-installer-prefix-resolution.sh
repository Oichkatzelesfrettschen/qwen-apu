#!/bin/sh
set -eu

# Prove that three installers place their products beneath the runtime root
# the resolver names, and that an explicit override still wins.
#
# Each script resolves its own default through `qwen-home.sh` --
# `qwen_home_shaderc_root` for the toolchain and the pack's compiler,
# `qwen_home_yacy` for the search peer -- so the claim under test is the
# resolution a run performs rather than the text of a usage line. Every arm
# gives the script a temporary root through QWEN_HOME and reads the path back
# out of the script's own message, so a default rewritten to a literal fails
# here even where the comment beside it still reads correctly.
#
# The arms stop at a refusal the script reaches before its first network
# request: the toolchain refuses a prefix that already exists, the pack
# refuses a glslc that is not executable, and the peer prints its clone
# target ahead of the clone. Stub programs satisfy the peer's `command -v`
# preflight so the run reaches that line on a machine holding no Java.
#
# usage: test-installer-prefix-resolution.sh

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

failures=0
report() {
    if [ "$2" = ok ]; then
        printf 'ok %s\n' "$1"
    else
        printf 'FAIL %s: %s\n' "$1" "$2"
        failures=$((failures + 1))
    fi
}

# A root outside every checkout, so a path that resolved from the tree rather
# than from QWEN_HOME lands outside it and the assertion catches it.
runtime_root=$work/nonstandard-root
mkdir -p "$runtime_root"

resolve() {
    QWEN_HOME=$runtime_root sh "$script_directory/qwen-home.sh" print "$1"
}

shaderc_root=$(resolve qwen_home_shaderc_root)
yacy_root=$(resolve qwen_home_yacy)

beneath() {
    case $1 in
        "$runtime_root"/*) return 0 ;;
        *) return 1 ;;
    esac
}

beneath "$shaderc_root" && report resolver_places_shaderc_beneath_the_root ok \
    || report resolver_places_shaderc_beneath_the_root "$shaderc_root"
beneath "$yacy_root" && report resolver_places_yacy_beneath_the_root ok \
    || report resolver_places_yacy_beneath_the_root "$yacy_root"

# ---- the toolchain default is the resolved shaderc root ----
# The prefix name comes from the ledger, so the arm reads it the way the
# script does rather than naming a version this test would have to track.
prefix_name=$(awk -F'\t' '
    /^#/ || NF == 0 { next }
    $1 == "prefix" { print $2; exit }
' "$script_directory/shaderc-toolchain.tsv")
if [ -z "$prefix_name" ]; then
    report toolchain_default_is_the_resolved_root 'the ledger names no prefix row'
else
    mkdir -p "$shaderc_root/$prefix_name"
    toolchain_log=$work/toolchain.log
    if QWEN_HOME=$runtime_root sh "$script_directory/fetch-shaderc-toolchain.sh" \
        >"$toolchain_log" 2>&1; then
        report toolchain_default_is_the_resolved_root 'the fetch accepted an existing prefix'
    else
        grep -q "the prefix already exists.*$shaderc_root/$prefix_name" "$toolchain_log" \
            && report toolchain_default_is_the_resolved_root ok \
            || report toolchain_default_is_the_resolved_root "$(tail -n 2 "$toolchain_log")"
    fi

    # ---- an explicit prefix root outranks the resolved default ----
    explicit_root=$work/explicit-prefix
    mkdir -p "$explicit_root/$prefix_name"
    explicit_log=$work/toolchain-explicit.log
    if QWEN_HOME=$runtime_root sh "$script_directory/fetch-shaderc-toolchain.sh" \
        "$explicit_root" >"$explicit_log" 2>&1; then
        report explicit_prefix_root_outranks_the_default 'the fetch accepted an existing prefix'
    else
        grep -q "the prefix already exists.*$explicit_root/$prefix_name" "$explicit_log" \
            && report explicit_prefix_root_outranks_the_default ok \
            || report explicit_prefix_root_outranks_the_default "$(tail -n 2 "$explicit_log")"
    fi

    # ---- the environment override outranks the resolved default ----
    environment_root=$work/environment-prefix
    mkdir -p "$environment_root/$prefix_name"
    environment_log=$work/toolchain-environment.log
    if QWEN_HOME=$runtime_root QWEN_SHADERC_PREFIX_ROOT=$environment_root \
        sh "$script_directory/fetch-shaderc-toolchain.sh" \
        >"$environment_log" 2>&1; then
        report environment_prefix_root_outranks_the_default 'the fetch accepted an existing prefix'
    else
        grep -q "the prefix already exists.*$environment_root/$prefix_name" "$environment_log" \
            && report environment_prefix_root_outranks_the_default ok \
            || report environment_prefix_root_outranks_the_default "$(tail -n 2 "$environment_log")"
    fi
fi

# ---- the pack reads its compiler from the resolved shaderc root ----
# The pack refuses an unexecutable glslc and names the path it resolved, which
# is the observation this arm reads; no shader is compiled.
pack_log=$work/pack.log
pack_declaration=$work/pack-declaration.tsv
pack_source=$work/pack-source
pack_output=$work/pack-output
: >"$pack_declaration"
mkdir -p "$pack_source"
if QWEN_HOME=$runtime_root sh "$script_directory/build-spirv-shader-pack.sh" \
    "$pack_declaration" "$pack_source" "$pack_output" >"$pack_log" 2>&1; then
    report pack_compiler_is_the_resolved_root 'the pack build accepted an absent glslc'
else
    grep -q "the pinned glslc is missing or not executable: $shaderc_root/" "$pack_log" \
        && report pack_compiler_is_the_resolved_root ok \
        || report pack_compiler_is_the_resolved_root "$(tail -n 2 "$pack_log")"
fi

# ---- the peer clones into the resolved yacy directory ----
# java, ant, and git satisfy the preflight as stubs so the run reaches its
# clone target on a machine holding none of them; the git stub then refuses,
# which keeps the arm off the network.
stub_bin=$work/stub-bin
mkdir -p "$stub_bin"
cat >"$stub_bin/java" <<'STUB'
#!/bin/sh
printf 'openjdk version "21.0.1" 2026-01-01\n' >&2
STUB
cat >"$stub_bin/ant" <<'STUB'
#!/bin/sh
exit 1
STUB
cat >"$stub_bin/git" <<'STUB'
#!/bin/sh
printf 'stub git refuses: %s\n' "$*" >&2
exit 1
STUB
chmod 755 "$stub_bin/java" "$stub_bin/ant" "$stub_bin/git"

yacy_log=$work/yacy.log
if PATH=$stub_bin:$PATH QWEN_HOME=$runtime_root \
    sh "$script_directory/install-yacy.sh" >"$yacy_log" 2>&1; then
    report yacy_default_is_the_resolved_root 'the install completed against a refusing git'
else
    grep -q "cloning pinned YaCy tag .* into $yacy_root$" "$yacy_log" \
        && report yacy_default_is_the_resolved_root ok \
        || report yacy_default_is_the_resolved_root "$(tail -n 2 "$yacy_log")"
fi

# ---- an explicit install directory outranks the resolved default ----
explicit_yacy=$work/explicit-yacy
explicit_yacy_log=$work/yacy-explicit.log
if PATH=$stub_bin:$PATH QWEN_HOME=$runtime_root \
    sh "$script_directory/install-yacy.sh" "$explicit_yacy" \
    >"$explicit_yacy_log" 2>&1; then
    report explicit_yacy_directory_outranks_the_default 'the install completed against a refusing git'
else
    grep -q "cloning pinned YaCy tag .* into $explicit_yacy$" "$explicit_yacy_log" \
        && report explicit_yacy_directory_outranks_the_default ok \
        || report explicit_yacy_directory_outranks_the_default "$(tail -n 2 "$explicit_yacy_log")"
fi

# ---- no installer names a home-directory prefix in its own text ----
# The executable defaults above resolve through the root; this arm holds the
# prose beside them to the same statement, so a usage line and a comment
# cannot describe a location the code stopped using.
# The pattern is assembled rather than written whole, so this file does not
# itself name the prefix `check-appliance-paths.py` refuses.
prefix_component=opt
for installer in fetch-shaderc-toolchain.sh build-spirv-shader-pack.sh install-yacy.sh; do
    if grep -nE "(~|[\$]HOME)/$prefix_component" "$script_directory/$installer" \
        >"$work/prose.log" 2>&1; then
        report "installer_prose_names_the_root_${installer%.sh}" "$(cat "$work/prose.log")"
    else
        report "installer_prose_names_the_root_${installer%.sh}" ok
    fi
done

if [ "$failures" -ne 0 ]; then
    printf 'installer_prefix_resolution=failed failures=%s\n' "$failures" >&2
    exit 1
fi
printf 'installer_prefix_resolution=passed\n'
