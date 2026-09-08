#!/bin/sh
set -eu

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/launch-readiness.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
fixture_remote=$temporary_directory/remote
fixture_home=$temporary_directory/runtime
mkdir -p "$fixture_remote" "$fixture_home/models" "$fixture_home/deployments/bundle"
cp "$script_directory/check-launch-readiness.sh" "$fixture_remote/"
cp "$script_directory/read-image-mcp-server.py" "$fixture_remote/"
cat >"$fixture_remote/qwen-home.sh" <<EOF
qwen_home=$fixture_home
qwen_home_deployments=$fixture_home/deployments
qwen_home_image_runtime=$fixture_home/opt/stable-diffusion.cpp/build-raven2/bin/sd-cli
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
printf '%s\n' "$accepted" | grep -q \
    '^launch_readiness=accepted scope=active-router-preset '
printf '%s\n' "$accepted" | grep -q '^checked_sections=1$'
printf '%s\n' "$accepted" | grep -q '^checked_web_sections=0$'
printf '%s\n' "$accepted" | grep -q '^checked_image_services=0$'
printf '%s\n' "$accepted" | grep -q '^checked_model_artifacts=1$'
printf '%s\n' "$accepted" | grep -q '^chat_history=preserved_in_browser_storage$'

# A tool-free roster does not depend on a search service that it cannot reach.
tool_free=$(FIXTURE_SEARXNG_STATUS=7 $fixture_remote/check-launch-readiness.sh)
printf '%s\n' "$tool_free" | grep -q '^launch_readiness=accepted '

image_parameters=$fixture_home/state/image-parameters.json
image_configuration=$fixture_home/deployments/bundle/web-image.json
image_runtime=$fixture_home/opt/stable-diffusion.cpp/build-raven2/bin/sd-cli
mkdir -p "$(dirname -- "$image_parameters")" "$(dirname -- "$image_runtime")"
printf '{}\n' >"$image_parameters"
printf '#!/bin/sh\nexit 0\n' >"$image_runtime"
chmod +x "$image_runtime"
cat >"$image_configuration" <<EOF
{"mcpServers":{"image":{"timeout_ms":30000,"env":{
"QWEN_IMAGE_LANGUAGE_PROFILE":"web-image","QWEN_IMAGE_PROFILE":"image-a",
"QWEN_IMAGE_TOKEN_KEY_FILE":"$fixture_home/state/image-token.key",
"QWEN_IMAGE_STATE_DIR":"$fixture_home/state/image",
"QWEN_IMAGE_SERVICE_SOCKET":"$fixture_home/state/image.sock",
"QWEN_IMAGE_PROFILES_JSON":"$image_parameters",
"QWEN_IMAGE_MCP_TIMEOUT_S":"30"}}}}
EOF
cat >"$fixture_home/deployments/bundle/router-presets.ini" <<EOF
# qwen_web_sections=web-image
# qwen_web_provider=searxng
[web-image]
LLAMA_ARG_MODEL = $model_path
LLAMA_ARG_MCP_SERVERS_CONFIG = $image_configuration
EOF
image_ready=$($fixture_remote/check-launch-readiness.sh)
printf '%s\n' "$image_ready" | grep -q '^checked_web_sections=1$'
printf '%s\n' "$image_ready" | grep -q '^checked_image_services=1$'
printf '%s\n' "$image_ready" | grep -q '^readiness=image-runtime state=present '

valid_image_configuration=$(cat "$image_configuration")
for invalid_configuration in \
    '{"mcpServers":[]}' \
    '{"mcpServers":"image"}' \
    '{"mcpServers":null}' \
    '[]'
do
    printf '%s\n' "$invalid_configuration" >"$image_configuration"
    if invalid_structure=$($fixture_remote/check-launch-readiness.sh 2>&1); then
        printf 'readiness accepted a structurally invalid MCP configuration: %s\n' \
            "$invalid_configuration" >&2
        exit 1
    fi
    printf '%s\n' "$invalid_structure" | grep -q \
        '^readiness=mcp-configuration state=missing .* reason=invalid-structure$'
done
printf '%s\n' "$valid_image_configuration" >"$image_configuration"

chmod -x "$image_runtime"
if missing_image_runtime=$($fixture_remote/check-launch-readiness.sh 2>&1); then
    printf 'readiness accepted an absent image runtime identity\n' >&2; exit 1
fi
printf '%s\n' "$missing_image_runtime" | grep -q \
    "readiness=image-runtime state=missing.*repair='make install-image-runtime'"
chmod +x "$image_runtime"
rm -f "$image_parameters"
if missing_image_parameters=$($fixture_remote/check-launch-readiness.sh 2>&1); then
    printf 'readiness accepted absent image parameters\n' >&2; exit 1
fi
printf '%s\n' "$missing_image_parameters" | grep -q \
    '^readiness=image-parameters state=missing '
printf '{}\n' >"$image_parameters"

if missing_searxng=$(FIXTURE_SEARXNG_STATUS=7 $fixture_remote/check-launch-readiness.sh 2>&1); then
    printf 'readiness accepted an absent SearXNG install for a SearXNG web section\n' >&2; exit 1
fi
printf '%s\n' "$missing_searxng" | grep -q \
    'readiness=searxng-install state=missing repair=make install-searxng && make verify-searxng status=7'

rm -f "$model_path"
if missing_model=$($fixture_remote/check-launch-readiness.sh 2>&1); then
    printf 'readiness accepted an absent referenced model\n' >&2; exit 1
fi
printf '%s\n' "$missing_model" | grep -q "readiness=model-artifact state=missing.*repair='make install-models'"
if missing_bundle=$(FIXTURE_DEPLOYMENT_STATUS=3 $fixture_remote/check-launch-readiness.sh 2>&1); then
    printf 'readiness accepted an absent active deployment\n' >&2; exit 1
fi
printf '%s\n' "$missing_bundle" | grep -q 'readiness=active-deployment state=missing'
printf 'launch readiness fixture: scoped roster, structural validation, and five refusal paths passed\n'
