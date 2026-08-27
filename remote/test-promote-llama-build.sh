#!/bin/sh
set -eu

# The promotion gate decides which binary serves, so a gate that passes an
# unchanged manifest and also passes a drifted one moves a build into service
# without checking it. Its first revision did exactly that: the drift filter
# expected three tab fields with a leading path where hash-load-closure.sh
# writes four with a basename, so it matched no row and every promotion passed.
# These checks run the gate against a fabricated build tree.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
promoter=$script_directory/promote-llama-build.sh
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT INT TERM
failures=0

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

preset=fixture-preset
build_directory=$work_directory/build-$preset
mkdir -p "$build_directory/bin"

# A shell script stands in for the executable: the gate runs `--version` and
# inspects the output of a one-token run, and both are behaviours rather than
# machine code.
cat >"$build_directory/bin/llama-server" <<'SERVER'
#!/bin/sh
[ "${1:-}" = --version ] && { printf 'version 0 (fixture)\n'; exit 0; }
exit 1
SERVER
chmod +x "$build_directory/bin/llama-server"
cp "$build_directory/bin/llama-server" "$build_directory/bin/llama-mtmd-cli"
printf 'fixture backend\n' >"$build_directory/bin/libggml-vulkan.so"

write_manifest() {
    {
        printf 'preset\t%s\n' "$preset"
        printf 'commit\t0000000000000000000000000000000000000000\n'
        printf 'worktree\tclean\n'
        for object_name in llama-server libggml-vulkan.so; do
            object_path=$build_directory/bin/$object_name
            printf 'linked\t%s\t%s\t%s\n' "$object_name" \
                "$(stat -c %s "$object_path")" \
                "$(sha256sum "$object_path" | cut -d ' ' -f 1)"
        done
    } >"$build_directory/artifact-manifest.tsv"
}
write_manifest

# No promotion model, so the strict Vulkan stage reports not-run instead of
# fabricating a pass, and the gate still has to reach its rename.
QWEN_PROMOTION_MODEL=$work_directory/absent.gguf
export QWEN_PROMOTION_MODEL

set +e
promotion_output=$("$promoter" "$preset" "$work_directory" 2>&1)
promotion_status=$?
set -e
case $promotion_status:$promotion_output in
    0:*strict_vulkan=not-run*multimodal=not-run*)
        report clean_manifest_promotes accepted ;;
    *) report clean_manifest_promotes rejected
       printf '%s\n' "$promotion_output" >&2 ;;
esac

if [ "$(readlink "$work_directory/build-appliance-current")" = "$build_directory" ]; then
    report current_link_points_at_preset accepted
else
    report current_link_points_at_preset rejected
fi

# One byte of drift in a backend object must stop the promotion.
printf 'fixture backend, rebuilt\n' >"$build_directory/bin/libggml-vulkan.so"
set +e
drift_output=$("$promoter" "$preset" "$work_directory" 2>&1)
drift_status=$?
set -e
case $drift_status:$drift_output in
    0:*) report drift_rejected rejected
         printf 'a drifted object promoted: %s\n' "$drift_output" >&2 ;;
    *:*libggml-vulkan.so\ changed*) report drift_rejected accepted ;;
    *) report drift_rejected rejected
       printf '%s\n' "$drift_output" >&2 ;;
esac
write_manifest

# A missing object is drift too, and it must not read as an empty check.
mv "$build_directory/bin/libggml-vulkan.so" "$build_directory/bin/libggml-vulkan.so.moved"
set +e
missing_output=$("$promoter" "$preset" "$work_directory" 2>&1)
missing_status=$?
set -e
case $missing_status:$missing_output in
    0:*) report missing_object_rejected rejected ;;
    *:*libggml-vulkan.so\ missing*) report missing_object_rejected accepted ;;
    *) report missing_object_rejected rejected
       printf '%s\n' "$missing_output" >&2 ;;
esac
mv "$build_directory/bin/libggml-vulkan.so.moved" "$build_directory/bin/libggml-vulkan.so"

# A manifest whose object rows are absent must fail rather than pass an empty
# loop, which is the defect this suite exists for.
{
    printf 'preset\t%s\n' "$preset"
    printf 'commit\t0000000000000000000000000000000000000000\n'
} >"$build_directory/artifact-manifest.tsv"
set +e
empty_output=$("$promoter" "$preset" "$work_directory" 2>&1)
empty_status=$?
set -e
case $empty_status:$empty_output in
    0:*) report empty_manifest_rejected rejected ;;
    *:*names\ no\ executable*) report empty_manifest_rejected accepted ;;
    *) report empty_manifest_rejected rejected
       printf '%s\n' "$empty_output" >&2 ;;
esac
write_manifest

# A first promotion retains nothing, because there was no target before it, and
# saying so beats rolling back to a link that was never set.
set +e
"$promoter" --rollback "$work_directory" >/dev/null 2>&1
first_rollback_status=$?
set -e
if [ "$first_rollback_status" -eq 1 ]; then
    report rollback_without_retained_target_refused accepted
else
    report rollback_without_retained_target_refused rejected
fi

# A second preset makes the retained target distinct from the current one, which
# is the case rollback exists for.
second_preset=fixture-preset-second
second_build_directory=$work_directory/build-$second_preset
mkdir -p "$second_build_directory/bin"
cp "$build_directory/bin/llama-server" "$second_build_directory/bin/llama-server"
cp "$build_directory/bin/llama-server" "$second_build_directory/bin/llama-mtmd-cli"
printf 'fixture backend, second arm\n' >"$second_build_directory/bin/libggml-vulkan.so"
{
    printf 'preset\t%s\n' "$second_preset"
    printf 'commit\t0000000000000000000000000000000000000000\n'
    printf 'worktree\tclean\n'
    for object_name in llama-server libggml-vulkan.so; do
        object_path=$second_build_directory/bin/$object_name
        printf 'linked\t%s\t%s\t%s\n' "$object_name" \
            "$(stat -c %s "$object_path")" \
            "$(sha256sum "$object_path" | cut -d ' ' -f 1)"
    done
} >"$second_build_directory/artifact-manifest.tsv"

set +e
"$promoter" "$second_preset" "$work_directory" >/dev/null 2>&1
second_status=$?
set -e
if [ "$second_status" -eq 0 ] &&
   [ "$(readlink "$work_directory/build-appliance-current")" = "$second_build_directory" ]; then
    report second_promotion_switches accepted
else
    report second_promotion_switches rejected
fi

set +e
rollback_output=$("$promoter" --rollback "$work_directory" 2>&1)
rollback_status=$?
set -e
if [ "$rollback_status" -eq 0 ] &&
   [ "$(readlink "$work_directory/build-appliance-current")" = "$build_directory" ]; then
    report rollback_restores accepted
else
    report rollback_restores rejected
    printf '%s\n' "$rollback_output" >&2
fi

# A preset that produced llama-server and no llama-mtmd-cli must refuse
# promotion. The vision profile is served by the same tree, so a promotion that
# accepted the absence would move a build into service whose projector path this
# gate never exercised.
mv "$build_directory/bin/llama-mtmd-cli" "$build_directory/bin/llama-mtmd-cli.moved"
set +e
multimodal_absent_output=$("$promoter" "$preset" "$work_directory" 2>&1)
multimodal_absent_status=$?
set -e
mv "$build_directory/bin/llama-mtmd-cli.moved" "$build_directory/bin/llama-mtmd-cli"
case $multimodal_absent_status:$multimodal_absent_output in
    0:*) report multimodal_cli_required rejected ;;
    *:*no\ executable\ llama-mtmd-cli*) report multimodal_cli_required accepted ;;
    *) report multimodal_cli_required rejected
       printf '%s\n' "$multimodal_absent_output" >&2 ;;
esac

set +e
"$promoter" >/dev/null 2>&1
usage_status=$?
"$promoter" no-such-preset "$work_directory" >/dev/null 2>&1
absent_status=$?
set -e
[ "$usage_status" -eq 2 ] && report usage_exit accepted || report usage_exit rejected
[ "$absent_status" -eq 1 ] && report absent_preset accepted || report absent_preset rejected

if [ "$failures" -eq 0 ]; then
    printf 'promote_llama_build=accepted\n'
    exit 0
fi
printf 'promote_llama_build=rejected failures=%s\n' "$failures" >&2
exit 1
