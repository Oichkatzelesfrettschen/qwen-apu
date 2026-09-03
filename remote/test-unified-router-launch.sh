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
    resolve-active-deployment.sh open-verified-lock-descriptor.py \
    select-projector.sh model-registry.sh models.tsv; do
    cp "$script_directory/$harness_member" "$harness/$harness_member"
done
# check-runtime-tree.sh reads a manifest beside the tree root and passes an
# unmanifested copy, which the harness is.
cp "$script_directory/check-runtime-tree.sh" "$harness/check-runtime-tree.sh"
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
        env "$@" "$harness/qwen-launch.sh" low-async
}

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
if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 \
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

if run_launch "$merged_preset" QWEN_BIND_HOST=0.0.0.0 QWEN_WEB_LAN=1 \
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
