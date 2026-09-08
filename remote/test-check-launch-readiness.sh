#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/launch-readiness.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
fixture_remote=$temporary_directory/remote
fixture_home=$temporary_directory/runtime
mkdir -p "$fixture_remote" "$fixture_home/models" "$fixture_home/deployments/bundle"
cp "$script_directory/check-launch-readiness.sh" "$fixture_remote/"
cat >"$fixture_remote/qwen-home.sh" <<EOF
qwen_home=$fixture_home
qwen_home_deployments=$fixture_home/deployments
export QWEN_HOME=\$qwen_home
EOF
write_authority() {
    authority_name=$1
    authority_body=$2
    printf '#!/bin/sh\n%s\n' "$authority_body" >"$fixture_remote/$authority_name"
    chmod +x "$fixture_remote/$authority_name"
}
write_authority runtime-root.sh 'exit "${FIXTURE_LAYOUT_STATUS:-0}"'
write_authority check-install-requirements.sh 'exit "${FIXTURE_REQUIREMENTS_STATUS:-0}"'
write_authority searxng-launch.sh 'exit "${FIXTURE_SEARXNG_STATUS:-0}"'
write_authority resolve-active-deployment.sh \
    'printf "active_deployment_router_presets=%s\\n" "$QWEN_HOME/deployments/bundle/router-presets.ini"; exit "${FIXTURE_DEPLOYMENT_STATUS:-0}"'
write_authority open-verified-lock-descriptor.py 'shift 3; exec "$@"'
: >"$fixture_home/deployments/.activate.lock"
chmod 600 "$fixture_home/deployments/.activate.lock"
model_path=$fixture_home/models/model.gguf
printf 'model\n' >"$model_path"
printf '[model]\nLLAMA_ARG_MODEL = %s\n' "$model_path" \
    >"$fixture_home/deployments/bundle/router-presets.ini"

accepted=$($fixture_remote/check-launch-readiness.sh)
printf '%s\n' "$accepted" | grep -q '^launch_readiness=accepted '
printf '%s\n' "$accepted" | grep -q '^chat_history=preserved_in_browser_storage$'
rm -f "$model_path"
if missing_model=$($fixture_remote/check-launch-readiness.sh 2>&1); then
    printf 'readiness accepted an absent referenced model\n' >&2; exit 1
fi
printf '%s\n' "$missing_model" | grep -q "readiness=model-artifact state=missing.*repair='make install-models'"
if missing_searxng=$(FIXTURE_SEARXNG_STATUS=7 $fixture_remote/check-launch-readiness.sh 2>&1); then
    printf 'readiness accepted an absent SearXNG install\n' >&2; exit 1
fi
printf '%s\n' "$missing_searxng" | grep -q \
    'readiness=searxng-install state=missing repair=make install-searxng && make verify-searxng status=7'
if missing_bundle=$(FIXTURE_DEPLOYMENT_STATUS=3 $fixture_remote/check-launch-readiness.sh 2>&1); then
    printf 'readiness accepted an absent active deployment\n' >&2; exit 1
fi
printf '%s\n' "$missing_bundle" | grep -q 'readiness=active-deployment state=missing'
printf 'launch readiness fixture: accepted and three refusal paths passed\n'
