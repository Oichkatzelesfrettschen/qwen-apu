#!/bin/sh
set -eu

# Compose the trace-capable source tree and build it as its own arm.
#
# The trace tree and serving tree share the eight-patch production closure in
# `remote/llama-patch-series.tsv`. The submit-trace member remains dormant until
# GGML_VK_SUBMIT_TRACE arms it, so the diagnostic build differs by its retained
# identity and runtime profile rather than by a stale source composition.
#
# The build itself runs through `remote/build-llama-preset.sh`, so the trace
# arm gets the production preset's flags, its output-timestamp proof, and its
# artifact manifest with the full load closure.

usage() {
    printf 'usage: %s [BASE_SOURCE [TRACE_SOURCE]]\n' "$0" >&2
    printf '\nBASE_SOURCE supplies the pinned upstream commit and defaults to\n' >&2
    printf 'src/llama.cpp under the home directory; TRACE_SOURCE receives the\n' >&2
    printf 'production patches and defaults to src/llama.cpp-qwen-apu-trace there.\n' >&2
    printf '\nenvironment:\n' >&2
    printf '  QWEN_TRACE_PREPARE_ONLY=1  compose the source and stop\n' >&2
    printf '  QWEN_BUILD_JOBS            forwarded to build-llama-preset.sh\n' >&2
    exit 2
}

[ "$#" -le 2 ] || usage
case ${1:-} in
    -h | --help) usage ;;
esac

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_directory=$(CDPATH='' cd -- "$script_directory/.." && pwd)
base_source=${1:-"${HOME:?}/src/llama.cpp"}
trace_source=${2:-"${HOME:?}/src/llama.cpp-qwen-apu-trace"}
# Repository source admission remains independent of the build environment.
status_checker=$script_directory/check-trace-source-status.sh
series_ledger=$script_directory/llama-patch-series.tsv
expected_commit=f280b26983ad0fdb705a0d9ebf0503e76f2899b0
trace_preset=raven2-vulkan-production

# The digests the eight-patch production replay produces, which is the set
# remote/verify-llama-patch-series.sh records.
trace_ggml_vulkan_sha256=dfac33fe7fd487fc136e2915de7d5c146a3921b231ffef55877c6dd9e4f2c164
trace_pacing_sha256=16abd2face079cad962bb722026d7418e65de67c18c1e1f954df733c1598a70a
trace_submit_limit_sha256=4b8befd927e9b0c83cfc7cfe843d2f853a9a9db7f6a55c147ffcd4129afd95f8
trace_submit_trace_sha256=ac957254c09afda811983801e7dd59d7e4829d40e572804ea7e23dadba521867
trace_llama_context_sha256=ecc818cdce4a7265f6f932962c325a582f42b91cb2661916fa28b5a79a49d1ad
trace_model_loader_sha256=d0d6c8725891ac4baf68fd947ab4be75cc93ba37b1e988ca1c556881a49d0abc
trace_server_sha256=d2d5cb43a83c6b2b459b85f2df181a3d976efcaef351e5cbc6b418ba839390e3
trace_server_context_sha256=3744317beb622feff234e5b7a615c50665579f34ce49921e324bcd418fb3a58a
# The legacy trace tree stopped after the router tools proxy member. Its Vulkan
# digest and exact path set admit only the two missing production suffixes.
legacy_trace_ggml_vulkan_sha256=d81e9093b4a3d98bf5cde8dc710ec187ddbaffca84540369cec72ecd132e575c
# tools/server/server.cpp before the router tools proxy patch. Naming it lets
# the refusal say which patch a stale tree is missing.
pre_router_server_sha256=2833d9d237e77a70a75736426f11432b964bc66f8e85c5751451f77444338703

if [ ! -d "$base_source/.git" ]; then
    printf 'base llama.cpp source repository is missing: %s\n' "$base_source" >&2
    exit 1
fi
if [ ! -x "$status_checker" ]; then
    printf 'trace source status checker is not executable: %s\n' \
        "$status_checker" >&2
    exit 1
fi
if [ ! -r "$series_ledger" ]; then
    printf 'patch series ledger is unreadable: %s\n' "$series_ledger" >&2
    exit 1
fi
production_patch_names=$(awk -F'\t' '
    /^#/ || NF == 0 { next }
    NF != 2 { printf "malformed patch series row: %s\n", $0 > "/dev/stderr"; bad = 1; next }
    $1 == "production" { print $2 }
    END { exit bad ? 1 : 0 }
' "$series_ledger")
if [ -z "$production_patch_names" ]; then
    printf 'patch series ledger names no production member: %s\n' \
        "$series_ledger" >&2
    exit 1
fi
production_patch_count=$(printf '%s\n' "$production_patch_names" | grep -c .)

if [ ! -e "$trace_source" ]; then
    git clone --local --no-hardlinks --no-checkout "$base_source" "$trace_source"
    git -C "$trace_source" checkout --quiet --detach "$expected_commit"
fi
if [ ! -d "$trace_source/.git" ]; then
    printf 'trace source repository is invalid: %s\n' "$trace_source" >&2
    exit 1
fi
actual_commit=$(git -C "$trace_source" rev-parse HEAD)
if [ "$actual_commit" != "$expected_commit" ]; then
    printf 'unexpected trace source commit: expected %s, found %s\n' \
        "$expected_commit" "$actual_commit" >&2
    exit 1
fi

source_matches() {
    expected_sha256=$1
    relative_path=$2
    [ -r "$trace_source/$relative_path" ] || return 1
    actual_sha256=$(sha256sum "$trace_source/$relative_path" | awk '{ print $1 }')
    [ "$actual_sha256" = "$expected_sha256" ]
}

trace_series_matches() {
    source_matches "$trace_ggml_vulkan_sha256" \
        ggml/src/ggml-vulkan/ggml-vulkan.cpp &&
    source_matches "$trace_pacing_sha256" \
        ggml/src/ggml-vulkan/ggml-vulkan-pacing.h &&
    source_matches "$trace_submit_limit_sha256" \
        ggml/src/ggml-vulkan/ggml-vulkan-submit-limit.h &&
    source_matches "$trace_submit_trace_sha256" \
        ggml/src/ggml-vulkan/ggml-vulkan-submit-trace.h &&
    source_matches "$trace_llama_context_sha256" src/llama-context.cpp &&
    source_matches "$trace_model_loader_sha256" src/llama-model-loader.cpp &&
    source_matches "$trace_server_sha256" tools/server/server.cpp &&
    source_matches "$trace_server_context_sha256" tools/server/server-context.cpp
}

legacy_six_patch_status=$(printf '%s\n' \
    ' M ggml/src/ggml-vulkan/ggml-vulkan.cpp' \
    ' M src/llama-context.cpp' \
    ' M src/llama-model-loader.cpp' \
    ' M tools/server/server.cpp' \
    '?? ggml/src/ggml-vulkan/ggml-vulkan-pacing.h' \
    '?? ggml/src/ggml-vulkan/ggml-vulkan-submit-limit.h' \
    '?? ggml/src/ggml-vulkan/ggml-vulkan-submit-trace.h' | LC_ALL=C sort)

apply_patches() {
    for patch_name in "$@"; do
        git -C "$trace_source" apply --check \
            "$repository_directory/patches/$patch_name"
        git -C "$trace_source" apply \
            "$repository_directory/patches/$patch_name"
    done
    git -C "$trace_source" diff --check
}

current_status=$(git -c core.fsmonitor=false -C "$trace_source" \
    status --porcelain=v1 --untracked-files=all | LC_ALL=C sort)
if trace_series_matches && "$status_checker" "$trace_source" >/dev/null; then
    prepared_state=already_verified
elif [ "$current_status" = "$legacy_six_patch_status" ] &&
     source_matches "$legacy_trace_ggml_vulkan_sha256" \
        ggml/src/ggml-vulkan/ggml-vulkan.cpp &&
     source_matches "$trace_pacing_sha256" \
        ggml/src/ggml-vulkan/ggml-vulkan-pacing.h &&
     source_matches "$trace_submit_limit_sha256" \
        ggml/src/ggml-vulkan/ggml-vulkan-submit-limit.h &&
     source_matches "$trace_submit_trace_sha256" \
        ggml/src/ggml-vulkan/ggml-vulkan-submit-trace.h &&
     source_matches "$trace_llama_context_sha256" src/llama-context.cpp &&
     source_matches "$trace_model_loader_sha256" src/llama-model-loader.cpp &&
     source_matches "$trace_server_sha256" tools/server/server.cpp; then
    apply_patches \
        llama-vulkan-view-alias-deps.patch \
        llama-server-natural-checkpoint-boundary.patch
    prepared_state=upgraded
else
    if [ -n "$current_status" ]; then
        if source_matches "$pre_router_server_sha256" tools/server/server.cpp; then
            printf 'trace source predates llama-router-tools-proxy.patch; use a fresh TRACE_SOURCE\n' >&2
        else
            printf 'trace source has unrecognized changes; refusing to overwrite %s\n' \
                "$trace_source" >&2
        fi
        git -C "$trace_source" status --short >&2
        exit 1
    fi
    # shellcheck disable=SC2046
    apply_patches $production_patch_names
    prepared_state=prepared
fi

if ! trace_series_matches; then
    printf 'trace source does not match the replayed eight-patch digests\n' >&2
    exit 1
fi
if ! "$status_checker" "$trace_source" >/dev/null; then
    printf 'trace source carries changes outside the exact eight-patch path set\n' >&2
    exit 1
fi

printf 'trace_source=%s path=%s commit=%s patch_count=%s\n' \
    "$prepared_state" "$trace_source" "$actual_commit" "$production_patch_count"

if [ "${QWEN_TRACE_PREPARE_ONLY:-0}" = 1 ]; then
    printf 'trace_build=skipped reason=prepare-only\n'
    exit 0
fi

"$script_directory/build-llama-preset.sh" "$trace_preset" "$trace_source"
printf 'trace_build=accepted directory=%s\n' \
    "$trace_source/build-$trace_preset"
