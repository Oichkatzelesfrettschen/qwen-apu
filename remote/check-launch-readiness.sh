#!/bin/sh
set -eu

# Read the existing appliance authorities while preserving runtime bytes.
[ "$#" -eq 0 ] || { printf 'usage: %s\n' "$0" >&2; exit 2; }
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

failures=0
check_result() {
    readiness_name=$1
    readiness_repair=$2
    shift 2
    readiness_output=''
    if readiness_output=$("$@" 2>&1); then
        printf 'readiness=%s state=present\n' "$readiness_name"
        [ -z "$readiness_output" ] || printf '%s\n' "$readiness_output"
    else
        readiness_status=$?
        printf 'readiness=%s state=missing repair=%s status=%s\n' \
            "$readiness_name" "$readiness_repair" "$readiness_status"
        [ -z "$readiness_output" ] || printf '%s\n' "$readiness_output" >&2
        failures=$((failures + 1))
    fi
}

check_result runtime-layout 'make bootstrap' \
    "$script_directory/runtime-root.sh" verify-layout
check_result laptop-requirements 'remote/check-install-requirements.sh laptop' \
    "$script_directory/check-install-requirements.sh" laptop
check_result searxng-install 'make install-searxng && make verify-searxng' \
    "$script_directory/searxng-launch.sh" check

deployment_report=''
activation_lock=$qwen_home_deployments/.activate.lock
if [ -f "$activation_lock" ] && deployment_report=$(
    QWEN_ACTIVATION_LOCK_DESCRIPTOR_INHERITED=1 \
        "$script_directory/open-verified-lock-descriptor.py" open \
        "$activation_lock" 7 "$script_directory/resolve-active-deployment.sh" 2>&1
); then
    printf 'readiness=active-deployment state=present\n%s\n' "$deployment_report"
else
    deployment_status=$?
    printf "readiness=active-deployment state=missing repair='remote/build-deployment-bundle.sh BUNDLE_NAME SERVER_PATH MANIFEST_PATH CTX_LEDGER && remote/activate-deployment-bundle.sh BUNDLE_NAME' status=%s\n" \
        "$deployment_status"
    [ -z "$deployment_report" ] || printf '%s\n' "$deployment_report" >&2
    failures=$((failures + 1))
fi

router_presets=$(printf '%s\n' "$deployment_report" |
    sed -n 's/^active_deployment_router_presets=//p' | head -n 1)
if [ -z "$router_presets" ] || [ "$router_presets" = - ] || [ ! -r "$router_presets" ]; then
    printf 'readiness=unified-router-preset state=missing repair=remote/build-deployment-bundle.sh\n'
    failures=$((failures + 1))
else
    printf 'readiness=unified-router-preset state=present path=%s\n' "$router_presets"
    referenced_paths=$(awk '
        {
            separator = index($0, "=")
            if (!separator) next
            key = substr($0, 1, separator - 1)
            value = substr($0, separator + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == "LLAMA_ARG_MODEL" || key == "LLAMA_ARG_MODEL_DRAFT" ||
                key == "LLAMA_ARG_MMPROJ") print value
        }
    ' "$router_presets" | LC_ALL=C sort -u)
    referenced_count=0
    missing_count=0
    while IFS= read -r referenced_path; do
        [ -n "$referenced_path" ] || continue
        referenced_count=$((referenced_count + 1))
        if [ -f "$referenced_path" ] && [ -r "$referenced_path" ]; then
            printf 'readiness=model-artifact state=present path=%s\n' "$referenced_path"
        else
            printf "readiness=model-artifact state=missing path=%s repair='make install-models'\n" \
                "$referenced_path"
            missing_count=$((missing_count + 1))
        fi
    done <<EOF
$referenced_paths
EOF
    if [ "$referenced_count" -eq 0 ]; then
        printf 'readiness=model-artifacts state=missing repair=remote/build-deployment-bundle.sh\n'
        failures=$((failures + 1))
    elif [ "$missing_count" -ne 0 ]; then
        failures=$((failures + 1))
    else
        printf 'readiness=model-artifacts state=present count=%s\n' "$referenced_count"
    fi
fi

if [ "$failures" -eq 0 ]; then
    printf 'launch_readiness=accepted qwen_home=%s\n' "$qwen_home"
    printf 'start=remote/qwen-lan-launch.sh_lan-authenticated_low-async\n'
    printf 'stop=remote/qwen-teardown.sh\n'
    printf 'chat_history=preserved_in_browser_storage\n'
    exit 0
fi
printf 'launch_readiness=refused failures=%s qwen_home=%s\n' "$failures" "$qwen_home"
exit 1
