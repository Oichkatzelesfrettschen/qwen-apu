#!/bin/sh
set -eu

# One router serves the whole roster, so the ordinary launcher arms the web
# lane from the preset rather than from a second wrapper. These checks run
# qwen-launch.sh against a recorder in place of qwen-webui-control.sh and read
# the environment it forwards across the tmux boundary, which is what decides
# whether qwen-webui-session.sh starts the approval broker and the search
# instance as guarded children and records them on its state=running line.
#
# A section reaching the network is exactly as guarded on the ordinary launch
# as on the web one: the bearer is required, the signing key is read whole
# before anything starts, the repository page is served in place of the pinned
# llama UI build, and a listener other than the loopback refuses without the
# LAN opt-in.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
failures=0
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = ok ] || failures=$((failures + 1))
}

# The launcher runs from a directory holding a recorder in place of
# qwen-webui-control.sh, so each arm reads the forwarded environment out of a
# file. Every other link it calls is the tree own file, since the arms measure
# what those links are handed.
harness=$work/harness
mkdir -p "$harness"
for harness_member in qwen-launch.sh web-lan-exposure.sh \
    resolve-active-deployment.sh deployment-bundle-name.sh \
    open-verified-lock-descriptor.py \
    select-projector.sh model-registry.sh models.tsv \
    image-launch-lib.sh read-image-mcp-server.py image-registry.sh \
    image-artifacts.tsv image-models.tsv image-quarantine.tsv \
    verify-deployment-bundle.sh verify-bundle-preset-ledger.sh; do
    cp "$script_directory/$harness_member" "$harness/$harness_member"
done
# remote/image-registry.sh resolves a retained evidence path against its own
# parent directory, so the harness mirrors the tree at that one point.
ln -s "$script_directory/../evidence" "$work/evidence"
# check-runtime-tree.sh reads a manifest beside the tree root and passes an
# unmanifested copy, which the harness is.
cp "$script_directory/check-runtime-tree.sh" "$harness/check-runtime-tree.sh"

# The interface-binding restriction reads ip -j addr and nmcli through
# remote/web-lan-exposure.sh's own overridable probes, so every LAN exposure
# arm below runs against a fixture interface carrying 192.168.1.10 rather
# than this host's own network.
lan_interface_probe=$harness/fake-ip
cat >"$lan_interface_probe" <<'EOF'
#!/bin/sh
printf '[{"ifindex":9,"ifname":"eth-test","address":"aa:bb:cc:dd:ee:ff","addr_info":[{"family":"inet","local":"192.168.1.10","prefixlen":24}]}]\n'
EOF
lan_connection_probe=$harness/fake-nmcli
cat >"$lan_connection_probe" <<'EOF'
#!/bin/sh
printf '11111111-1111-1111-1111-111111111111:test-lan:eth-test\n'
EOF
chmod 755 "$lan_interface_probe" "$lan_connection_probe"
QWEN_LAN_INTERFACE_PROBE="$lan_interface_probe -j addr"
QWEN_LAN_CONNECTION_PROBE="$lan_connection_probe -t -f UUID,NAME,DEVICE connection show --active"
QWEN_WEB_LAN_TRUSTED_CONNECTIONS=11111111-1111-1111-1111-111111111111
export QWEN_LAN_INTERFACE_PROBE QWEN_LAN_CONNECTION_PROBE \
    QWEN_WEB_LAN_TRUSTED_CONNECTIONS
cat >"$harness/qwen-teardown.sh" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$harness/qwen-teardown.sh"
cat >"$harness/qwen-webui-control.sh" <<'EOF'
#!/bin/sh
set -eu
{
    printf 'argument=%s\n' "${2:-unset}"
    printf 'QWEN_ROUTER=%s\n' "${QWEN_ROUTER:-unset}"
    printf 'QWEN_ROUTER_PRESETS=%s\n' "${QWEN_ROUTER_PRESETS:-unset}"
    printf 'QWEN_ROUTER_MAX=%s\n' "${QWEN_ROUTER_MAX:-unset}"
    printf 'QWEN_BIND_HOST=%s\n' "${QWEN_BIND_HOST:-unset}"
    printf 'QWEN_WEB_BROKER=%s\n' "${QWEN_WEB_BROKER:-unset}"
    printf 'QWEN_WEB_BROKER_PORT=%s\n' "${QWEN_WEB_BROKER_PORT:-unset}"
    printf 'QWEN_WEB_STATE_DIR=%s\n' "${QWEN_WEB_STATE_DIR:-unset}"
    printf 'QWEN_WEB_TOKEN_KEY_FILE=%s\n' "${QWEN_WEB_TOKEN_KEY_FILE:-unset}"
    printf 'QWEN_WEB_PROFILE=%s\n' "${QWEN_WEB_PROFILE:-unset}"
    printf 'QWEN_WEB_PROVIDER=%s\n' "${QWEN_WEB_PROVIDER:-unset}"
    printf 'QWEN_WEB_PROFILES=%s\n' "${QWEN_WEB_PROFILES:-unset}"
    printf 'QWEN_WEB_SEARXNG=%s\n' "${QWEN_WEB_SEARXNG:-unset}"
    printf 'QWEN_SEARXNG_PORT=%s\n' "${QWEN_SEARXNG_PORT:-unset}"
    printf 'QWEN_STATIC_PATH=%s\n' "${QWEN_STATIC_PATH:-unset}"
    printf 'QWEN_REQUIRE_API_KEY=%s\n' "${QWEN_REQUIRE_API_KEY:-unset}"
    printf 'QWEN_WEB_LAN=%s\n' "${QWEN_WEB_LAN:-unset}"
    printf 'QWEN_WEB_LAN_ADDRESS=%s\n' "${QWEN_WEB_LAN_ADDRESS:-unset}"
    printf 'QWEN_WEB_LAN_NAME=%s\n' "${QWEN_WEB_LAN_NAME:-unset}"
    printf 'QWEN_WEB_LAN_OPEN=%s\n' "${QWEN_WEB_LAN_OPEN:-unset}"
    printf 'QWEN_IMAGE_SERVICE=%s\n' "${QWEN_IMAGE_SERVICE:-unset}"
    printf 'QWEN_IMAGE_SERVICE_PROGRAM=%s\n' "${QWEN_IMAGE_SERVICE_PROGRAM:-unset}"
    printf 'QWEN_IMAGE_PROFILE=%s\n' "${QWEN_IMAGE_PROFILE:-unset}"
    printf 'QWEN_IMAGE_PROFILES=%s\n' "${QWEN_IMAGE_PROFILES:-unset}"
    printf 'QWEN_IMAGE_PROFILES_JSON=%s\n' "${QWEN_IMAGE_PROFILES_JSON:-unset}"
    printf 'QWEN_IMAGE_TOKEN_KEY_FILE=%s\n' "${QWEN_IMAGE_TOKEN_KEY_FILE:-unset}"
    printf 'QWEN_REQUIRED_VULKAN_MIB=%s\n' "${QWEN_REQUIRED_VULKAN_MIB:-unset}"
} >"$QWEN_LAUNCH_RECORD"
printf 'state=running recorder=1\n' >"$QWEN_WEBUI_STATE_DIRECTORY/session.status"
EOF
chmod +x "$harness/qwen-webui-control.sh"

# The launcher waits for /health on the listener it reports, so the harness
# answers that route from a standard-library server for the duration of a run.
health_port=18086
python3 - "$health_port" "$work/health.pid" <<'PY' &
import http.server
import socketserver
import sys

port = int(sys.argv[1])


class Health(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200 if self.path.startswith("/health") else 404)
        self.end_headers()
        self.wfile.write(b"{}")

    def log_message(self, *arguments):
        return


socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", port), Health) as server:
    server.serve_forever()
PY
health_server_pid=$!
trap 'kill "$health_server_pid" 2>/dev/null; rm -rf "$work"' EXIT HUP INT TERM
health_attempt=0
while [ "$health_attempt" -lt 100 ]; do
    if curl --silent --fail "http://127.0.0.1:$health_port/health" \
        >/dev/null 2>&1; then
        break
    fi
    health_attempt=$((health_attempt + 1))
    sleep 0.1
done

# The page the launcher reads carries the two route shapes the approval path
# depends on, so the arm measures the check rather than the checked-in file.
mkdir -p "$work/webui"
# shellcheck disable=SC2016
printf '%s\n' \
    'fetch(`./tools?model=${encodeURIComponent(selectedModel)}&autoload=true`)' \
    'JSON.stringify({ model, tool: toolName, params, stream: false })' \
    'const IMAGE_GENERATION_TIMEOUT_MS = 420000;' \
    >"$work/webui/index.html"

model_root=$work/models
mkdir -p "$model_root/Fixture-GGUF"
printf 'weights\n' >"$model_root/Fixture-GGUF/production.gguf"

token_key_file=$work/token.key
printf 'fixture-signing-key\n' >"$token_key_file"
chmod 600 "$token_key_file"
api_key_file=$work/state/api.key

state_directory=$work/state
mkdir -p "$state_directory/web-mcp-configs"
mcp_config=$state_directory/web-mcp-configs/web-fixture.json
printf '{"mcpServers":{}}\n' >"$mcp_config"
printf 'fixture-api-key\n' >"$api_key_file"
chmod 600 "$api_key_file"

web_profiles=$work/web-profiles.tsv
printf '# profile_id\tmodel_id\tweb_mode\tcontext\tvalidated_filled_depth\tmax_results\tmax_fetches\tmax_chars_per_fetch\tmulti_source\tvision_allowed\ttool_selection\texecution_policy\tprovider\tprimary_category\tfallback_category\tminimum_results\tsearxng_url\n' \
    >"$web_profiles"
printf 'web-fixture\tfixture-production\tvalidator-gated\t8192\t16384\t5\t2\t12000\tyes\tno\t9/10\tvalidator-gated\tsearxng\tqwen-open\t-\t1\thttp://127.0.0.1:18888\n' \
    >>"$web_profiles"

write_preset() {
    preset_path=$1
    preset_sections=$2
    {
        printf '# Generated by remote/build-router-presets.sh from the model registry.\n'
        printf '# qwen_router_include_quarantine=0\n'
        printf '# qwen_web_sections=%s\n' "$preset_sections"
        if [ "$preset_sections" = '-' ]; then
            printf '# qwen_web_profiles_path=-\n'
            printf '# qwen_web_profiles_sha256=-\n'
            printf '# qwen_web_provider=-\n'
        else
            printf '# qwen_web_profiles_path=%s\n' "$web_profiles"
            printf '# qwen_web_profiles_sha256=%s\n' \
                "$(sha256sum "$web_profiles" | cut -d' ' -f1)"
            printf '# qwen_web_provider=searxng\n'
        fi
        printf '\n[fixture-production]\n'
        printf 'LLAMA_ARG_MODEL = %s/Fixture-GGUF/production.gguf\n' "$model_root"
        printf 'LLAMA_ARG_CTX_CHECKPOINTS = 0\n\n'
        if [ "$preset_sections" != '-' ]; then
            printf '[%s]\n' "$preset_sections"
            printf 'LLAMA_ARG_MODEL = %s/Fixture-GGUF/production.gguf\n' \
                "$model_root"
            printf 'LLAMA_ARG_CTX_CHECKPOINTS = 0\n'
            printf 'LLAMA_ARG_MCP_SERVERS_CONFIG = %s\n' "$mcp_config"
            printf 'LLAMA_ARG_TAGS = web-research,validator-gated,production\n\n'
        fi
    } >"$preset_path"
}

tool_free_preset=$work/router-presets-tool-free.ini
write_preset "$tool_free_preset" -
merged_preset=$work/router-presets-merged.ini
write_preset "$merged_preset" web-fixture

# The image lane rides the same preset. The ledger fixture names the checked-in
# bundle and differs from the shipped row in execution_policy and review_model
# alone, so remote/image-registry.sh validates it whole against the artifact and
# model authorities the harness copied.
image_profiles=$work/image-profiles.tsv
printf 'image-fixture-a\tsdxs-512\tA\t512\t512\t1\teuler\t1.0\t4\t512\t300\tvalidator-gated\tevidence/image-appliance/design.md\t-\n' \
    >"$image_profiles"
image_runtime=$work/fake-image-runtime.sh
printf '#!/bin/sh\nexit 0\n' >"$image_runtime"
chmod +x "$image_runtime"
image_parameters=$work/image-parameters.json
cat >"$image_parameters" <<PARAMETERS
{
  "image-fixture-a": {
    "profile_id": "image-fixture-a",
    "model_id": "sdxs-512",
    "placement": "A",
    "width": 512,
    "height": 512,
    "steps": 1,
    "sampler": "euler",
    "cfg": 1.0,
    "max_steps": 4,
    "max_dimension": 512,
    "timeout_s": 300,
    "execution_policy": "validator-gated",
    "runtime_path": "$image_runtime",
    "runtime_argv": ["--output", "{output}"]
  }
}
PARAMETERS
image_mcp_config=$state_directory/web-mcp-configs/web-fixture-image.json
cat >"$image_mcp_config" <<CONFIGURATION
{
  "mcpServers": {
    "web": {"command": "python3", "args": [], "env": {}},
    "image": {
      "command": "python3",
      "timeout_ms": 360000,
      "args": ["$script_directory/image-mcp/server.py"],
      "env": {
        "QWEN_IMAGE_LANGUAGE_PROFILE": "web-fixture",
        "QWEN_IMAGE_PROFILE": "image-fixture-a",
        "QWEN_IMAGE_TOKEN_KEY_FILE": "$token_key_file",
        "QWEN_IMAGE_STATE_DIR": "$state_directory/images",
        "QWEN_IMAGE_SERVICE_SOCKET": "$state_directory/images/image-service.sock",
        "QWEN_IMAGE_PROFILES_JSON": "$image_parameters",
        "QWEN_IMAGE_MCP_TIMEOUT_S": "360"
      }
    }
  }
}
CONFIGURATION
# model-memory-preflight.sh reads the device, so the harness answers for it with
# the two lines the launch reads.
memory_preflight=$work/fake-memory-preflight.sh
cat >"$memory_preflight" <<'PREFLIGHT'
#!/bin/sh
set -eu
printf 'model_bytes=%s\n' "$(wc -c <"$1")"
printf 'vulkan_required_mib=%s\n' "$2"
printf 'vulkan_budget_headroom=ample\n'
PREFLIGHT
chmod +x "$memory_preflight"
imaged_preset=$work/router-presets-imaged.ini
{
    sed 's|^LLAMA_ARG_MCP_SERVERS_CONFIG = .*|LLAMA_ARG_MCP_SERVERS_CONFIG = '"$image_mcp_config"'|' \
        "$merged_preset"
} >"$imaged_preset.body"
awk -v ledger="$image_profiles" \
    -v digest="$(sha256sum "$image_profiles" | cut -d' ' -f1)" '
    { print }
    /^# qwen_web_provider=/ {
        printf "# qwen_image_profiles_path=%s\n", ledger
        printf "# qwen_image_profiles_sha256=%s\n", digest
        printf "# qwen_image_profile=image-fixture-a\n"
        printf "# qwen_image_model=sdxs-512\n"
        printf "# qwen_image_mcp_timeout_ms=360000\n"
        printf "# qwen_image_review_model=-\n"
        printf "# qwen_image_review_section=-\n"
    }
' "$imaged_preset.body" >"$imaged_preset"

record=$work/launch.record
run_launch() {
    run_preset=$1
    shift
    QWEN_WEBUI_STATE_DIRECTORY=$state_directory \
    QWEN_LAUNCH_RECORD=$record \
    QWEN_ROUTER=1 \
    QWEN_ROUTER_PRESETS=$run_preset \
    QWEN_MODEL_PATH=$model_root/Fixture-GGUF/production.gguf \
    QWEN_SERVER_PORT=$health_port \
    QWEN_READY_ATTEMPTS=60 \
    QWEN_DEPLOYMENT_ROOT=$work/deployments \
    QWEN_LLAMA_SERVER=$harness/qwen-teardown.sh \
    QWEN_MMPROJ='' \
    QWEN_STATIC_PATH=$work/webui \
    QWEN_WEB_TOKEN_KEY_FILE=$token_key_file \
    QWEN_WEB_AUTHORIZER_READY=1 \
    QWEN_WEB_LAN_NAME='' \
        env "$@" "$harness/qwen-launch.sh" low-async
}
# QWEN_WEB_LAN_NAME is set empty above rather than left unset, because an unset
# value is the question web-lan-exposure.sh answers from this host's own avahi
# state: an arm that inherited it would resolve a different name on a machine
# running the daemon and would print that machine's hostname into a log. Every
# name arm states its own synthetic value.

# A preset holding registry sections alone starts no broker and no search
# instance, so an ordinary roster launch reaches no network at all.
if run_launch "$tool_free_preset" env -u QWEN_BIND_HOST \
    >"$work/tool-free.log" 2>"$work/tool-free.err"; then
    outcome=ok
    grep -qx 'QWEN_WEB_BROKER=unset' "$record" || outcome=broker_armed
    grep -qx 'QWEN_WEB_SEARXNG=unset' "$record" || outcome=searxng_armed
    grep -qx 'QWEN_REQUIRE_API_KEY=unset' "$record" || outcome=key_forced
    grep -qx 'QWEN_ROUTER_MAX=unset' "$record" || outcome=models_max_set
    report tool_free_launch_starts_no_children "$outcome"
else
    report tool_free_launch_starts_no_children failed
    cat "$work/tool-free.err" >&2
fi

# A preset carrying one web section arms both guarded children, requires the
# bearer, names the profile the broker signs for, and serves the repository
# page.
if run_launch "$merged_preset" env -u QWEN_BIND_HOST \
    >"$work/merged.log" 2>"$work/merged.err"; then
    outcome=ok
    grep -qx 'QWEN_WEB_BROKER=1' "$record" || outcome=broker_unarmed
    grep -qx 'QWEN_WEB_BROKER_PORT=8571' "$record" || outcome=wrong_broker_port
    grep -qx 'QWEN_WEB_SEARXNG=1' "$record" || outcome=searxng_unarmed
    grep -qx 'QWEN_SEARXNG_PORT=18888' "$record" || outcome=wrong_searxng_port
    grep -qx 'QWEN_REQUIRE_API_KEY=1' "$record" || outcome=key_not_required
    grep -qx 'QWEN_WEB_PROFILE=web-fixture' "$record" || outcome=profile_underived
    grep -qx 'QWEN_WEB_PROVIDER=searxng' "$record" || outcome=provider_dropped
    grep -qx "QWEN_WEB_PROFILES=$web_profiles" "$record" || outcome=ledger_dropped
    grep -qx "QWEN_WEB_TOKEN_KEY_FILE=$token_key_file" "$record" ||
        outcome=key_path_dropped
    grep -qx "QWEN_STATIC_PATH=$work/webui" "$record" || outcome=page_dropped
    grep -qx 'QWEN_BIND_HOST=127.0.0.1' "$record" || outcome=wrong_bind_host
    # The launcher leaves the model limit to the capacity policy default of 1,
    # since one router child at a time is what the 2048 MiB carve-out holds.
    grep -qx 'QWEN_ROUTER_MAX=unset' "$record" || outcome=models_max_raised
    grep -q 'web_section=web-fixture provider=searxng' "$work/merged.log" ||
        outcome=section_unreported
    if grep -q 'fixture-signing-key' "$work/merged.log" "$work/merged.err"; then
        outcome=key_contents_printed
    fi
    report web_section_launch_arms_children "$outcome"
else
    report web_section_launch_arms_children failed
    cat "$work/merged.err" >&2
fi

# A preset carrying the image marker arms the generation service beside the
# broker and the search instance, so one launch serves chat, search, and
# generation. The requirement the session preflights against composes with the
# subject selection: the image runtime is charged on top of the largest servable
# checkpoint, since `--models-max 1` keeps the roster's sections from being
# co-resident while the runtime runs beside the loaded child.
if run_launch "$imaged_preset" env -u QWEN_BIND_HOST \
    QWEN_IMAGE_SERVICE_PROGRAM="$script_directory/image-service.py" \
    QWEN_IMAGE_PROFILES_JSON="$image_parameters" \
    QWEN_MEMORY_PREFLIGHT_PROGRAM="$memory_preflight" \
    QWEN_IMAGE_RUNTIME_RESIDENT_MIB=480 \
    >"$work/imaged.log" 2>"$work/imaged.err"; then
    outcome=ok
    grep -qx 'QWEN_IMAGE_SERVICE=1' "$record" || outcome=service_unarmed
    grep -qx 'QWEN_IMAGE_PROFILE=image-fixture-a' "$record" ||
        outcome=profile_dropped
    grep -qx "QWEN_IMAGE_PROFILES=$image_profiles" "$record" ||
        outcome=ledger_dropped
    grep -qx "QWEN_IMAGE_PROFILES_JSON=$image_parameters" "$record" ||
        outcome=parameters_dropped
    grep -qx "QWEN_IMAGE_TOKEN_KEY_FILE=$token_key_file" "$record" ||
        outcome=key_path_dropped
    grep -q '^QWEN_IMAGE_SERVICE_PROGRAM=.*image-service\.py$' "$record" ||
        outcome=program_dropped
    grep -qx 'QWEN_REQUIRED_VULKAN_MIB=5088' "$record" ||
        outcome=budget_uncharged
    grep -qx 'QWEN_WEB_BROKER=1' "$record" || outcome=broker_unarmed
    grep -qx 'QWEN_WEB_SEARXNG=1' "$record" || outcome=searxng_unarmed
    grep -q 'image_launch budget subject_mib=4608 runtime_mib=480 required_mib=5088' \
        "$work/imaged.log" || outcome=budget_unreported
    grep -q '^vulkan_budget_headroom=ample' "$work/imaged.log" ||
        outcome=preflight_unreported
    grep -q 'image_launch timeouts ' "$work/imaged.log" ||
        outcome=deadlines_unreported
    report image_lane_launch_arms_the_service "$outcome"
else
    report image_lane_launch_arms_the_service failed
    cat "$work/imaged.err" >&2
fi

# image-registry.sh's identifier() admits a period after the first character,
# and a ledger-valid id such as sdxs.512-arm-a carries one, so the marker
# vocabulary qwen-capacity-policy.sh checks has to match it rather than
# rejecting a preset the ledger already accepted. A private copy of the
# ledger carries the row, because the shared $image_profiles file is the one
# every other arm's preset already bound a digest to.
image_profiles_dotted=$work/image-profiles-dotted.tsv
cp -- "$image_profiles" "$image_profiles_dotted"
printf 'sdxs.512-arm-a\tsdxs-512\tA\t512\t512\t1\teuler\t1.0\t4\t512\t300\tvalidator-gated\tevidence/image-appliance/design.md\t-\n' \
    >>"$image_profiles_dotted"
image_parameters_dotted=$work/image-parameters-dotted.json
sed 's/"image-fixture-a"/"sdxs.512-arm-a"/' "$image_parameters" \
    >"$image_parameters_dotted"
image_mcp_config_dotted=$state_directory/web-mcp-configs/web-fixture-image-dotted.json
sed 's/"QWEN_IMAGE_PROFILE": "image-fixture-a"/"QWEN_IMAGE_PROFILE": "sdxs.512-arm-a"/;
     s|"QWEN_IMAGE_PROFILES_JSON": "'"$image_parameters"'"|"QWEN_IMAGE_PROFILES_JSON": "'"$image_parameters_dotted"'"|' \
    "$image_mcp_config" >"$image_mcp_config_dotted"
imaged_preset_dotted=$work/router-presets-imaged-dotted.ini
awk -v ledger="$image_profiles_dotted" \
    -v digest="$(sha256sum "$image_profiles_dotted" | cut -d' ' -f1)" \
    -v config="$image_mcp_config_dotted" '
    /^LLAMA_ARG_MCP_SERVERS_CONFIG = / {
        print "LLAMA_ARG_MCP_SERVERS_CONFIG = " config
        next
    }
    /^# qwen_image_profiles_path=/ {
        print "# qwen_image_profiles_path=" ledger
        next
    }
    /^# qwen_image_profiles_sha256=/ {
        print "# qwen_image_profiles_sha256=" digest
        next
    }
    /^# qwen_image_profile=image-fixture-a$/ {
        print "# qwen_image_profile=sdxs.512-arm-a"
        next
    }
    { print }
' "$imaged_preset" >"$imaged_preset_dotted"
if run_launch "$imaged_preset_dotted" env -u QWEN_BIND_HOST \
    QWEN_IMAGE_SERVICE_PROGRAM="$script_directory/image-service.py" \
    QWEN_IMAGE_PROFILES_JSON="$image_parameters_dotted" \
    QWEN_MEMORY_PREFLIGHT_PROGRAM="$memory_preflight" \
    QWEN_IMAGE_RUNTIME_RESIDENT_MIB=480 \
    >"$work/imaged-dotted.log" 2>"$work/imaged-dotted.err"; then
    outcome=ok
    grep -qx 'QWEN_IMAGE_SERVICE=1' "$record" || outcome=service_unarmed
    grep -qx 'QWEN_IMAGE_PROFILE=sdxs.512-arm-a' "$record" ||
        outcome=profile_dropped
    report image_profile_marker_admits_a_period "$outcome"
else
    report image_profile_marker_admits_a_period failed
    cat "$work/imaged-dotted.err" >&2
fi

# A preset carrying no image marker is one generated before this lane, so the
# launch arms no service and charges nothing for a runtime it never starts.
if run_launch "$merged_preset" env -u QWEN_BIND_HOST \
    >"$work/no-image.log" 2>"$work/no-image.err"; then
    outcome=ok
    grep -qx 'QWEN_IMAGE_SERVICE=unset' "$record" || outcome=service_armed
    grep -qx 'QWEN_REQUIRED_VULKAN_MIB=unset' "$record" || outcome=budget_charged
    report marker_free_preset_arms_no_image_service "$outcome"
else
    report marker_free_preset_arms_no_image_service failed
    cat "$work/no-image.err" >&2
fi

# qwen-web-launch.sh execs this launcher, so a launch that came through
# qwen-image-launch.sh arrives with the lane already resolved and its own
# requirement already charged. One owner per launch: this one reports what it
# inherited rather than resolving a second time against a file whose section
# list it never wrote, and the requirement it forwards is the wrapper's. The
# ambient QWEN_IMAGE_SERVICE_PROGRAM, QWEN_IMAGE_PROFILES_JSON, and
# QWEN_IMAGE_TOKEN_KEY_FILE are the same three export_image_service_environment
# set when the wrapper resolved the lane, so this arm carries them the way a
# real inherited launch does: the claim is validated against a fresh read of
# the preset rather than trusted outright.
if run_launch "$imaged_preset" env -u QWEN_BIND_HOST \
    QWEN_IMAGE_SERVICE=1 QWEN_IMAGE_PROFILE=image-fixture-a \
    QWEN_IMAGE_SERVICE_PROGRAM="$script_directory/image-service.py" \
    QWEN_IMAGE_PROFILES_JSON="$image_parameters" \
    QWEN_IMAGE_TOKEN_KEY_FILE="$token_key_file" \
    QWEN_REQUIRED_VULKAN_MIB=3210 \
    >"$work/inherited.log" 2>"$work/inherited.err"; then
    outcome=ok
    grep -q 'image_launch owner=qwen-image-launch.sh profile=image-fixture-a required_mib=3210' \
        "$work/inherited.log" || outcome=owner_unreported
    grep -qx 'QWEN_REQUIRED_VULKAN_MIB=3210' "$record" || outcome=budget_recharged
    grep -q 'image_launch budget subject_mib=' "$work/inherited.log" &&
        outcome=lane_resolved_twice
    report inherited_image_lane_is_reported_once "$outcome"
else
    report inherited_image_lane_is_reported_once failed
    cat "$work/inherited.err" >&2
fi

# A stale QWEN_IMAGE_SERVICE=1 left in a calling shell from an earlier
# wrapper launch, carried into a direct qwen-launch.sh invocation over a
# preset naming no image profile, is refused rather than trusted: nothing
# validated that this launch's own preset agrees with the inherited claim.
if run_launch "$merged_preset" env -u QWEN_BIND_HOST \
    QWEN_IMAGE_SERVICE=1 QWEN_IMAGE_PROFILE=image-fixture-a \
    QWEN_IMAGE_SERVICE_PROGRAM="$script_directory/image-service.py" \
    QWEN_IMAGE_PROFILES_JSON="$image_parameters" \
    QWEN_IMAGE_TOKEN_KEY_FILE="$token_key_file" \
    QWEN_REQUIRED_VULKAN_MIB=3210 \
    >"$work/stale-inherited.log" 2>"$work/stale-inherited.err"; then
    report stale_inherited_image_flag_refused admitted
elif grep -q 'this preset names no image profile' \
    "$work/stale-inherited.err"; then
    report stale_inherited_image_flag_refused ok
else
    report stale_inherited_image_flag_refused wrong_reason
    cat "$work/stale-inherited.err" >&2
fi

# The launch reads the bundle's own web-mcp-manifest.tsv and compares each
# recorded digest against the file the child will read, so the record's row
# shape is a claim two programs make and this arm is where they meet. A record
# whose fourth column the reader folded into the digest refused every image
# bundle on the appliance while the bundle itself verified, which
# remote/test-deployment-bundle.sh could not see: it exercises the writer and
# the verifier, and neither reads the row the way the launcher does.
bundle_root=$work/deployments
mkdir -p "$bundle_root"
bundle_registry=$work/bundle-models.tsv
printf 'fixture-production\tfast-text\tFixture-GGUF/production.gguf\n' \
    >"$bundle_registry"
bundle_ledger=$work/bundle-ctx-checkpoints.tsv
printf '# the fixture bundle admits no checkpoint count\n' >"$bundle_ledger"
bundle_server=$work/bundle-llama-server
printf '#!/bin/sh\nexit 0\n' >"$bundle_server"
chmod 755 "$bundle_server"
bundle_manifest=$work/bundle-artifact-manifest.tsv
{
    printf 'checkpoint_semantics\tforced-tail-v1\n'
    printf 'executable\tllama-server\t%s\t%s\n' \
        "$(wc -c <"$bundle_server" | tr -d ' ')" \
        "$(sha256sum "$bundle_server" | cut -d ' ' -f 1)"
} >"$bundle_manifest"
if QWEN_MODEL_REGISTRY=$bundle_registry \
    QWEN_MODEL_ROOT=$model_root \
    QWEN_BUNDLE_ROUTER_PRESETS=$imaged_preset \
    "$script_directory/build-deployment-bundle.sh" bundle-imaged \
        "$bundle_server" "$bundle_manifest" "$bundle_ledger" "$bundle_root" \
    >"$work/bundle.log" 2>"$work/bundle.err" &&
    QWEN_MODEL_REGISTRY=$bundle_registry \
    "$script_directory/activate-deployment-bundle.sh" bundle-imaged \
        "$bundle_root" >"$work/activate.log" 2>"$work/activate.err"; then
    recorded_row=$(grep '^web-fixture	' \
        "$bundle_root/bundle-imaged/web-mcp-manifest.tsv")
    outcome=ok
    case $recorded_row in
        *"	image") ;;
        *) outcome=image_column_absent ;;
    esac
    # The launch resolves the bundle rather than reading the state directory,
    # so QWEN_ROUTER_PRESETS and QWEN_LLAMA_SERVER are both withheld: an
    # explicit server outranks the deployment and would read no bundle at all.
    if QWEN_MODEL_REGISTRY=$bundle_registry \
        QWEN_CTX_CHECKPOINT_LEDGER=$bundle_ledger \
        run_launch "$imaged_preset" env -u QWEN_ROUTER_PRESETS \
        -u QWEN_LLAMA_SERVER \
        QWEN_DEPLOYMENT_ROOT="$bundle_root" \
        QWEN_IMAGE_SERVICE_PROGRAM="$script_directory/image-service.py" \
        QWEN_IMAGE_PROFILES_JSON="$image_parameters" \
        QWEN_MEMORY_PREFLIGHT_PROGRAM="$memory_preflight" \
        >"$work/bundle-launch.log" 2>"$work/bundle-launch.err"; then
        grep -q "web_mcp_configurations=verified record=$bundle_root/bundle-imaged/web-mcp-manifest.tsv" \
            "$work/bundle-launch.log" || outcome=record_unverified
        grep -qx 'QWEN_IMAGE_SERVICE=1' "$record" || outcome=service_unarmed
        grep -q 'changed since the bundle recorded it' \
            "$work/bundle-launch.err" && outcome=digest_misread
    else
        outcome=launch_refused
        cat "$work/bundle-launch.err" >&2
    fi
    report launch_accepts_the_image_bundle_record "$outcome"
else
    report launch_accepts_the_image_bundle_record bundle_failed
    cat "$work/bundle.err" "$work/activate.err" >&2
fi

# An image row moved to refused after generation revokes the lane, and the
# ledger digest the preset binds reads the edit before anything starts.
sed 's/\tvalidator-gated\t/\trefused\t/' "$image_profiles" \
    >"$work/image-refused.tsv"
cp -- "$work/image-refused.tsv" "$image_profiles"
if run_launch "$imaged_preset" env -u QWEN_BIND_HOST \
    QWEN_IMAGE_SERVICE_PROGRAM="$script_directory/image-service.py" \
    QWEN_IMAGE_PROFILES_JSON="$image_parameters" \
    QWEN_MEMORY_PREFLIGHT_PROGRAM="$memory_preflight" \
    >"$work/image-revoked.log" 2>"$work/image-revoked.err"; then
    report revoked_image_ledger_refuses_the_launch admitted
elif grep -q 'image profile ledger identity changed' \
    "$work/image-revoked.err"; then
    report revoked_image_ledger_refuses_the_launch ok
else
    report revoked_image_ledger_refuses_the_launch wrong_reason
    cat "$work/image-revoked.err" >&2
fi

# A section reaching the network serves the loopback unless the operator
# decided otherwise, so an ordinary launch on the wildcard refuses.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 \
    >"$work/lan-absent.log" 2>"$work/lan-absent.err"; then
    report lan_bind_without_opt_in_refused admitted
elif grep -q 'a web section reaches the network through its MCP server' \
    "$work/lan-absent.err"; then
    report lan_bind_without_opt_in_refused ok
else
    report lan_bind_without_opt_in_refused wrong_reason
    cat "$work/lan-absent.err" >&2
fi

# The opt-in names one routable IPv4 literal and requires the bearer file
# whole, which is the policy remote/web-lan-exposure.sh states for the web
# launcher and this launch applies unchanged.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 \
    >"$work/lan.log" 2>"$work/lan.err"; then
    outcome=ok
    grep -qx 'QWEN_WEB_LAN=1' "$record" || outcome=marker_dropped
    grep -qx 'QWEN_WEB_LAN_ADDRESS=192.168.1.10' "$record" ||
        outcome=address_dropped
    grep -qx 'QWEN_BIND_HOST=0.0.0.0' "$record" || outcome=wrong_bind_host
    grep -qx 'QWEN_REQUIRE_API_KEY=1' "$record" || outcome=key_not_required
    report lan_exposure_admitted "$outcome"
else
    report lan_exposure_admitted refused
    cat "$work/lan.err" >&2
fi

# The mDNS name joins the literal as a second admitted host, and the page URL
# leads with it, because a DHCP lease moves the literal and the name does not.
# The key line stays off a redirected stdout, which is what this arm's own
# output file is.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=qwen-test.local \
    >"$work/lan-named.log" 2>"$work/lan-named.err"; then
    outcome=ok
    grep -qx 'QWEN_WEB_LAN_NAME=qwen-test.local' "$record" || outcome=name_dropped
    grep -q 'lan_name=qwen-test.local' "$work/lan-named.log" ||
        outcome=name_unreported
    grep -q 'the page is at http://qwen-test.local:'"$health_port"'/ (and http://192.168.1.10:'"$health_port"'/)' \
        "$work/lan-named.log" || outcome=page_url_unnamed
    grep -q '#key=' "$work/lan-named.log" && outcome=key_on_redirected_stdout
    report lan_exposure_admits_the_mdns_name "$outcome"
else
    report lan_exposure_admits_the_mdns_name refused
    cat "$work/lan-named.err" >&2
fi

# QWEN_WEB_LAN_OPEN=0 is the authenticated LAN bring-up, and
# admit_web_lan_exposure requires $state_directory/api.key to already exist
# before it admits the exposure. qwen-webui-session.sh's own minting runs
# deep inside the tmux session this launch has not started yet, so a fresh
# state directory with no api.key would previously refuse here before
# anything ever minted it. This arm removes the fixture's key to prove the
# launch mints its own ahead of that check, then restores the fixture value
# so later arms reading a fixed key content are unaffected.
rm -f "$api_key_file"
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_OPEN=0 \
    QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    >"$work/lan-fresh-key.log" 2>"$work/lan-fresh-key.err"; then
    outcome=ok
    [ -s "$api_key_file" ] || outcome=key_not_minted
    [ "$(stat -c %a "$api_key_file")" = 600 ] || outcome=key_wrong_mode
    grep -qx '[0-9a-f]\{64\}' "$api_key_file" || outcome=key_wrong_shape
    report authenticated_lan_launch_mints_a_fresh_api_key "$outcome"
else
    report authenticated_lan_launch_mints_a_fresh_api_key refused
    cat "$work/lan-fresh-key.err" >&2
fi
printf 'fixture-api-key\n' >"$api_key_file"
chmod 600 "$api_key_file"

# A symlink at the api.key path is refused outright rather than minted or
# chmod'd through: `[ -s ... ]` and chmod both follow a link, so writing
# through one would overwrite or change the mode of whatever it points at
# ahead of admit_web_lan_exposure's own `[ -L ... ]` refusal.
api_key_symlink_target=$work/state/elsewhere
printf 'untouched\n' >"$api_key_symlink_target"
chmod 644 "$api_key_symlink_target"
rm -f "$api_key_file"
ln -s "$api_key_symlink_target" "$api_key_file"
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_OPEN=0 \
    >"$work/lan-symlinked-key.log" 2>"$work/lan-symlinked-key.err"; then
    report lan_api_key_symlink_refused admitted
else
    outcome=ok
    grep -q 'the Web UI API key path names a symlink' \
        "$work/lan-symlinked-key.err" || outcome=wrong_reason
    [ "$(cat "$api_key_symlink_target")" = untouched ] || outcome=target_overwritten
    [ "$(stat -c %a "$api_key_symlink_target")" = 644 ] || outcome=target_chmodded
    report lan_api_key_symlink_refused "$outcome"
fi
rm -f "$api_key_file"
printf 'fixture-api-key\n' >"$api_key_file"
chmod 600 "$api_key_file"

# A directory at the api.key path is refused the same way, before chmod runs
# against it: `[ -L ... ]` alone admits a FIFO, device, or directory, and a
# directory losing its own permissions to chmod 600 is exactly the kind of
# damage the symlink check alone does not prevent.
rm -f "$api_key_file"
mkdir "$api_key_file"
api_key_directory_mode=$(stat -c %a "$api_key_file")
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_OPEN=0 \
    >"$work/lan-directory-key.log" 2>"$work/lan-directory-key.err"; then
    report lan_api_key_non_regular_refused admitted
else
    outcome=ok
    grep -q 'names neither nothing nor a regular file' \
        "$work/lan-directory-key.err" || outcome=wrong_reason
    [ "$(stat -c %a "$api_key_file")" = "$api_key_directory_mode" ] ||
        outcome=target_chmodded
    report lan_api_key_non_regular_refused "$outcome"
fi
rmdir "$api_key_file"
printf 'fixture-api-key\n' >"$api_key_file"
chmod 600 "$api_key_file"

# The key line is guarded by the terminal test itself rather than by the
# absence of a match above, so the arm reads the source for that guard.
if grep -q '\[ -t 1 \] && \[ -s "\$state_directory/api.key" \]' \
    "$script_directory/qwen-launch.sh"; then
    report lan_key_line_guarded_by_a_terminal_test ok
else
    report lan_key_line_guarded_by_a_terminal_test guard_absent
fi

# The same launch over a pseudo-terminal prints the key, which is what makes
# the arm above a measurement of the guard rather than of an absent feature.
# `script` allocates that terminal; a host without it reports the arm as unrun.
if command -v script >/dev/null 2>&1; then
    cat >"$work/tty-launch.sh" <<TTY
#!/bin/sh
set -eu
exec env QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \\
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=qwen-test.local \\
    QWEN_WEBUI_STATE_DIRECTORY=$state_directory QWEN_LAUNCH_RECORD=$record \\
    QWEN_ROUTER=1 QWEN_ROUTER_PRESETS=$merged_preset \\
    QWEN_MODEL_PATH=$model_root/Fixture-GGUF/production.gguf \\
    QWEN_SERVER_PORT=$health_port QWEN_READY_ATTEMPTS=60 \\
    QWEN_DEPLOYMENT_ROOT=$work/deployments \\
    QWEN_LLAMA_SERVER=$harness/qwen-teardown.sh QWEN_MMPROJ='' \\
    QWEN_STATIC_PATH=$work/webui QWEN_WEB_TOKEN_KEY_FILE=$token_key_file \\
    QWEN_WEB_AUTHORIZER_READY=1 \\
    $harness/qwen-launch.sh low-async
TTY
    chmod +x "$work/tty-launch.sh"
    if script -qec "$work/tty-launch.sh" /dev/null \
        >"$work/lan-tty.log" 2>"$work/lan-tty.err"; then
        outcome=ok
        grep -q "the page with the key is at http://qwen-test.local:$health_port/#key=fixture-api-key" \
            "$work/lan-tty.log" || outcome=key_line_absent
        report lan_key_line_printed_on_a_terminal "$outcome"
    else
        report lan_key_line_printed_on_a_terminal refused
        cat "$work/lan-tty.err" "$work/lan-tty.log" >&2
    fi
else
    printf 'lan_key_line_printed_on_a_terminal=not_run reason=script_absent\n'
fi

# A name outside the letter-digit-hyphen set names no host a browser resolves,
# so the launch refuses it rather than adding an entry no request matches.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME='qwen test.local' \
    >"$work/lan-badname.log" 2>"$work/lan-badname.err"; then
    report lan_exposure_name_refused admitted
elif grep -q 'not a hostname a browser resolves on the link' \
    "$work/lan-badname.err"; then
    report lan_exposure_name_refused ok
else
    report lan_exposure_name_refused wrong_reason
    cat "$work/lan-badname.err" >&2
fi

# A bare hostname carries no .local suffix and registers in the ordinary
# resolver, so the launch refuses it rather than admitting a name DNS
# rebinding could steer to this address.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=qwen-test \
    >"$work/lan-barehost.log" 2>"$work/lan-barehost.err"; then
    report lan_exposure_bare_hostname_refused admitted
elif grep -q 'not a hostname a browser resolves on the link' \
    "$work/lan-barehost.err"; then
    report lan_exposure_bare_hostname_refused ok
else
    report lan_exposure_bare_hostname_refused wrong_reason
    cat "$work/lan-barehost.err" >&2
fi

# A public domain resolves through the ordinary recursive resolver, which is
# the DNS rebinding surface the closed .local set exists to close, so the
# launch refuses it by name.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=attacker.example.com \
    >"$work/lan-publicdomain.log" 2>"$work/lan-publicdomain.err"; then
    report lan_exposure_public_domain_refused admitted
elif grep -q 'not a hostname a browser resolves on the link' \
    "$work/lan-publicdomain.err"; then
    report lan_exposure_public_domain_refused ok
else
    report lan_exposure_public_domain_refused wrong_reason
    cat "$work/lan-publicdomain.err" >&2
fi

# An uppercase label registers in the ordinary resolver the way a lowercase
# one does, so the launch refuses it rather than reshaping it into a name the
# operator never typed.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=QWEN-Test.LOCAL \
    >"$work/lan-case.log" 2>"$work/lan-case.err"; then
    report lan_exposure_name_refuses_uppercase admitted
elif grep -q 'not a hostname a browser resolves on the link' \
    "$work/lan-case.err"; then
    report lan_exposure_name_refuses_uppercase ok
else
    report lan_exposure_name_refuses_uppercase wrong_reason
    cat "$work/lan-case.err" >&2
fi

# A trailing dot names the DNS root explicitly, a form the multicast lookup
# does not need, so the launch refuses it.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=qwen-test.local. \
    >"$work/lan-trailingdot.log" 2>"$work/lan-trailingdot.err"; then
    report lan_exposure_trailing_dot_refused admitted
elif grep -q 'not a hostname a browser resolves on the link' \
    "$work/lan-trailingdot.err"; then
    report lan_exposure_trailing_dot_refused ok
else
    report lan_exposure_trailing_dot_refused wrong_reason
    cat "$work/lan-trailingdot.err" >&2
fi

# LOCALHOST carries no .local suffix under a case-sensitive comparison, so
# web_lan_name_is_valid refuses it the same way it refuses any other bare
# hostname; the check runs before any lowercasing, so an uppercase caller
# value is refused by name rather than reshaped into a name the operator
# never typed.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=LOCALHOST \
    QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    >"$work/lan-badname-case.log" 2>"$work/lan-badname-case.err"; then
    report lan_exposure_localhost_case_variant_refused admitted
elif grep -q 'not a hostname a browser resolves on the link' \
    "$work/lan-badname-case.err"; then
    report lan_exposure_localhost_case_variant_refused ok
else
    report lan_exposure_localhost_case_variant_refused wrong_reason
    cat "$work/lan-badname-case.err" >&2
fi

# A derived broker port at or beyond the top of the valid TCP range overflows
# when the session derives the artifact port one higher again, the same
# overflow remote/qwen-lan-launch.sh's own 65533 cap on QWEN_SERVER_PORT
# exists to keep out of its wrapper path; a direct LAN launch through
# qwen-launch.sh carries no such bound before this fix.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_SERVER_PORT=65535 \
    >"$work/lan-port-overflow.log" 2>"$work/lan-port-overflow.err"; then
    report lan_derived_port_overflow_refused admitted
elif grep -q 'leaves room for the broker and artifact ports above it' \
    "$work/lan-port-overflow.err"; then
    report lan_derived_port_overflow_refused ok
else
    report lan_derived_port_overflow_refused wrong_reason
    cat "$work/lan-port-overflow.err" >&2
fi

# QWEN_WEB_LAN_OPEN=1 removes a bearer from a listener the operator exposed,
# so a launch exposing none refuses rather than serving an authenticated
# loopback while the operator believes the credential is gone.
if run_launch "$merged_preset" env -u QWEN_BIND_HOST QWEN_WEB_LAN_OPEN=1 \
    >"$work/lan-open-alone.log" 2>"$work/lan-open-alone.err"; then
    report lan_open_refused_without_exposure admitted
elif grep -q 'removes the bearer from a LAN listener, and this launch exposes none' \
    "$work/lan-open-alone.err"; then
    report lan_open_refused_without_exposure ok
else
    report lan_open_refused_without_exposure wrong_reason
    cat "$work/lan-open-alone.err" >&2
fi

# The admitted open exposure leaves QWEN_REQUIRE_API_KEY at 0 across the tmux
# boundary and states on stdout what every peer on the network can then do.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_NAME=qwen-test.local \
    QWEN_WEB_LAN_OPEN=1 \
    >"$work/lan-open.log" 2>"$work/lan-open.err"; then
    outcome=ok
    grep -qx 'QWEN_REQUIRE_API_KEY=0' "$record" || outcome=key_still_required
    grep -qx 'QWEN_WEB_LAN_OPEN=1' "$record" || outcome=open_marker_dropped
    grep -q 'lan_open=1 every peer on this network can chat, approve a search, and approve a generation' \
        "$work/lan-open.log" || outcome=open_unreported
    grep -q '#key=' "$work/lan-open.log" && outcome=key_line_printed
    report lan_open_admitted "$outcome"
else
    report lan_open_admitted refused
    cat "$work/lan-open.err" >&2
fi

# The open opt-in meets both research overrides on the exposure's own terms,
# since it names the exposure and the exposure refuses each.
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_ADDRESS=192.168.1.10 QWEN_WEB_LAN_OPEN=1 \
    QWEN_ROUTER_INCLUDE_QUARANTINE=1 \
    >"$work/lan-open-quarantine.log" 2>"$work/lan-open-quarantine.err"; then
    report lan_open_refuses_the_quarantine_override admitted
elif grep -q 'recorded device failure serves the loopback' \
    "$work/lan-open-quarantine.err"; then
    report lan_open_refuses_the_quarantine_override ok
else
    report lan_open_refuses_the_quarantine_override wrong_reason
    cat "$work/lan-open-quarantine.err" >&2
fi

if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_ADDRESS=qwen-laptop \
    >"$work/lan-name.log" 2>"$work/lan-name.err"; then
    report lan_address_name_refused admitted
elif grep -q 'not a routable IPv4 literal' "$work/lan-name.err"; then
    report lan_address_name_refused ok
else
    report lan_address_name_refused wrong_reason
    cat "$work/lan-name.err" >&2
fi

# One broker signs for one profile, so a preset naming two web sections
# refuses rather than leaving the browser to learn it after an approval.
two_section_preset=$work/router-presets-two.ini
sed 's/^# qwen_web_sections=web-fixture$/# qwen_web_sections=web-fixture,web-second/' \
    "$merged_preset" >"$two_section_preset"
if run_launch "$two_section_preset" env -u QWEN_BIND_HOST \
    >"$work/two.log" 2>"$work/two.err"; then
    report two_web_sections_refused admitted
elif grep -q 'one broker signs for one profile' "$work/two.err"; then
    report two_web_sections_refused ok
else
    report two_web_sections_refused wrong_reason
    cat "$work/two.err" >&2
fi

# The signing key is read whole before anything starts, so a broker that would
# refuse the first approval a human has already given never launches.
if run_launch "$merged_preset" env -u QWEN_BIND_HOST \
    QWEN_WEB_TOKEN_KEY_FILE="$work/absent.key" \
    >"$work/key.log" 2>"$work/key.err"; then
    report absent_signing_key_refused admitted
elif grep -q 'grant signing key is not a regular file' "$work/key.err"; then
    report absent_signing_key_refused ok
else
    report absent_signing_key_refused wrong_reason
    cat "$work/key.err" >&2
fi

# An MCP configuration the preset names and this machine holds no file for
# fails the child at startup well after the listener is up, so it refuses here.
absent_config_preset=$work/router-presets-absent-config.ini
sed "s|^LLAMA_ARG_MCP_SERVERS_CONFIG = .*|LLAMA_ARG_MCP_SERVERS_CONFIG = $work/absent.json|" \
    "$merged_preset" >"$absent_config_preset"
if run_launch "$absent_config_preset" env -u QWEN_BIND_HOST \
    >"$work/absent-config.log" 2>"$work/absent-config.err"; then
    report absent_mcp_configuration_refused admitted
elif grep -q 'names LLAMA_ARG_MCP_SERVERS_CONFIG and this machine holds no file' \
    "$work/absent-config.err"; then
    report absent_mcp_configuration_refused ok
else
    report absent_mcp_configuration_refused wrong_reason
    cat "$work/absent-config.err" >&2
fi

# The pinned llama UI build neither scopes GET /tools by model nor posts the
# routing key beside the tool, so a directory holding it refuses before the
# listener exists.
mkdir -p "$work/other-page"
printf '<html></html>\n' >"$work/other-page/index.html"
if run_launch "$merged_preset" env -u QWEN_BIND_HOST \
    QWEN_STATIC_PATH="$work/other-page" \
    >"$work/page.log" 2>"$work/page.err"; then
    report foreign_page_refused admitted
elif grep -q 'composes no model-scoped /tools request' "$work/page.err"; then
    report foreign_page_refused ok
else
    report foreign_page_refused wrong_reason
    cat "$work/page.err" >&2
fi

if [ "$failures" -eq 0 ]; then
    printf 'test-unified-router-launch: all checks passed\n'
else
    printf 'test-unified-router-launch: %s check(s) failed\n' "$failures" >&2
    exit 1
fi
