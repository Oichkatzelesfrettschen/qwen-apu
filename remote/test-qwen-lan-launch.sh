#!/bin/sh
set -eu

# The LAN bring-up states the exposure environment once and hands it to
# qwen-launch.sh. These checks run qwen-lan-launch.sh against recorders in
# place of qwen-launch.sh and qwen-teardown.sh and read what each was handed:
# the port, the derived address, the open opt-in, the minted signing key, and
# the order in which a running session ends before the new one starts.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
failures=0
work=$(mktemp -d)
QWEN_HOME=$work/runtime
export QWEN_HOME
trap 'rm -rf "$work"' EXIT HUP INT TERM

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = ok ] || failures=$((failures + 1))
}

harness=$work/harness
mkdir -p "$harness/web-mcp"
cp "$script_directory/qwen-lan-launch.sh" "$harness/qwen-lan-launch.sh"
cp "$script_directory/qwen-home.sh" "$harness/qwen-home.sh"
cp "$script_directory/read-image-mcp-server.py" "$harness/read-image-mcp-server.py"
: >"$harness/web-mcp/server.py"

# The deployment fixture is a preset naming two MCP configurations, one for
# a web-only section and one carrying the image server, so the wrapper reads
# the parameters path from the image server through the tree's own reader.
deployment=$work/deployment
mkdir -p "$deployment"
printf '{}\n' >"$deployment/deployed-parameters.json"
printf '{"mcpServers":{}}\n' >"$deployment/web-only.json"
cat >"$deployment/web-image.json" <<CONFIGURATION
{
  "mcpServers": {
    "web": {"command": "python3", "args": [], "env": {}},
    "image": {
      "command": "python3",
      "timeout_ms": 360000,
      "args": ["$harness/image-mcp/server.py"],
      "env": {
        "QWEN_IMAGE_LANGUAGE_PROFILE": "web-open",
        "QWEN_IMAGE_PROFILE": "image-fixture-a",
        "QWEN_IMAGE_TOKEN_KEY_FILE": "$deployment/image-token.key",
        "QWEN_IMAGE_STATE_DIR": "$deployment/images",
        "QWEN_IMAGE_SERVICE_SOCKET": "$deployment/images/image-service.sock",
        "QWEN_IMAGE_PROFILES_JSON": "$deployment/deployed-parameters.json",
        "QWEN_IMAGE_MCP_TIMEOUT_S": "360"
      }
    }
  }
}
CONFIGURATION
cat >"$deployment/router-presets.ini" <<PRESET
[fixture-production]
LLAMA_ARG_MODEL=$deployment/fixture.gguf

[web-reader]
LLAMA_ARG_MODEL=$deployment/fixture.gguf
LLAMA_ARG_MCP_SERVERS_CONFIG=$deployment/web-only.json

[web-open]
LLAMA_ARG_MODEL=$deployment/fixture.gguf
LLAMA_ARG_MCP_SERVERS_CONFIG = $deployment/web-image.json
PRESET
cat >"$harness/resolve-active-deployment.sh" <<'EOF'
#!/bin/sh
set -eu
[ "${QWEN_TEST_RESOLVER_STATUS:-0}" = 0 ] || exit "$QWEN_TEST_RESOLVER_STATUS"
printf 'active_deployment_directory=%s\n' "$QWEN_TEST_DEPLOYMENT"
printf 'active_deployment_router_presets=%s/router-presets.ini\n' "$QWEN_TEST_DEPLOYMENT"
EOF

# The launch recorder writes the environment it received and the session
# record a real launch leaves behind, so the wrapper reads the name from the
# same line the session writes.
cat >"$harness/qwen-launch.sh" <<'EOF'
#!/bin/sh
set -eu
{
    printf 'profile=%s\n' "${1:-}"
    env | grep '^QWEN_' | sort
} >"$QWEN_TEST_LAUNCH_RECORD"
mkdir -p "$QWEN_WEBUI_STATE_DIRECTORY"
printf 'state=running server_pid=1 lan_exposure=1 lan_address=%s lan_name=%s lan_open=%s port=%s\n' \
    "$QWEN_WEB_LAN_ADDRESS" "${QWEN_TEST_LAN_NAME:-}" "$QWEN_WEB_LAN_OPEN" "$QWEN_SERVER_PORT" \
    >"$QWEN_WEBUI_STATE_DIRECTORY/session.status"
exit "${QWEN_TEST_LAUNCH_STATUS:-0}"
EOF
cat >"$harness/qwen-teardown.sh" <<'EOF'
#!/bin/sh
set -eu
printf 'teardown\n' >>"$QWEN_TEST_TEARDOWN_RECORD"
rm -f "$QWEN_WEBUI_STATE_DIRECTORY/session.status"
exit "${QWEN_TEST_TEARDOWN_STATUS:-0}"
EOF
cat >"$harness/probe-address" <<'EOF'
#!/bin/sh
printf '%s\n' "${QWEN_TEST_PROBE_ANSWER:-}"
EOF
chmod 755 "$harness/qwen-lan-launch.sh" "$harness/qwen-launch.sh" \
    "$harness/qwen-teardown.sh" "$harness/probe-address" \
    "$harness/resolve-active-deployment.sh" "$harness/read-image-mcp-server.py"

home=$work/home
state=$home/qwen-webui-state
mkdir -p "$state"
launch_record=$work/launch.record
teardown_record=$work/teardown.record

run_wrapper() {
    rm -f "$launch_record"
    HOME=$home \
    QWEN_WEBUI_STATE_DIRECTORY=$state \
    QWEN_TEST_LAUNCH_RECORD=$launch_record \
    QWEN_TEST_TEARDOWN_RECORD=$teardown_record \
    QWEN_TEST_LAN_NAME=laptop.local \
    QWEN_TEST_DEPLOYMENT=$deployment \
    QWEN_LAN_ADDRESS_PROBE=$harness/probe-address \
    QWEN_TEST_PROBE_ANSWER=${QWEN_TEST_PROBE_ANSWER-10.0.0.7} \
        "$harness/qwen-lan-launch.sh" "$@"
}

recorded() {
    grep -qx "$1" "$launch_record"
}

# Two positional arguments are a usage error.
if run_wrapper low-async extra >"$work/usage.out" 2>"$work/usage.err"; then
    report usage_refused fail
else
    [ "$?" -eq 2 ] && report usage_refused ok || report usage_refused fail
fi

# The first bring-up derives the address, mints the key, forwards the whole
# exposure set, and prints the name from the session record.
if run_wrapper >"$work/first.out" 2>"$work/first.err"; then
    report first_launch_exit ok
else
    report first_launch_exit fail
    cat "$work/first.err" >&2
fi
if recorded 'profile=low-async' &&
    recorded 'QWEN_SERVER_PORT=42069' &&
    recorded 'QWEN_WEB_LAN=1' &&
    recorded 'QWEN_WEB_LAN_ADDRESS=10.0.0.7' &&
    recorded 'QWEN_WEB_LAN_OPEN=0' &&
    recorded 'QWEN_WEB_LAN_OPEN_ALL_INTERFACES=0' &&
    ! grep -qx 'QWEN_BIND_HOST=.*' "$launch_record" &&
    recorded 'QWEN_ROUTER=1' &&
    recorded 'QWEN_WEB_AUTHORIZER_READY=1' &&
    recorded "QWEN_WEB_TOKEN_KEY_FILE=$QWEN_HOME/state/web-token.key" &&
    recorded "QWEN_WEB_MCP_SERVER=$harness/web-mcp/server.py" &&
    recorded 'QWEN_WEB_PROVIDER=searxng' &&
    recorded "QWEN_IMAGE_PROFILES_JSON=$deployment/deployed-parameters.json" &&
    grep -q " image_parameters_source=active-deployment$" "$work/first.out"; then
    report exposure_environment_forwarded ok
else
    report exposure_environment_forwarded fail
    cat "$launch_record" >&2
fi
if [ "$(stat -c %a "$QWEN_HOME/state/web-token.key")" = 600 ] &&
    [ "$(wc -c <"$QWEN_HOME/state/web-token.key")" -eq 65 ] &&
    grep -qx '[0-9a-f]\{64\}' "$QWEN_HOME/state/web-token.key"; then
    report signing_key_minted ok
else
    report signing_key_minted fail
fi
first_key=$(cat "$QWEN_HOME/state/web-token.key")
if grep -q '^prior_session=none$' "$work/first.out" &&
    grep -q ' signing_key=minted ' "$work/first.out" &&
    grep -q ' address_source=default-route ' "$work/first.out" &&
    grep -qx 'open http://laptop.local:42069/ from any machine on this network' "$work/first.out" &&
    grep -qx 'or http://10.0.0.7:42069/ by address while this lease holds' "$work/first.out" &&
    [ ! -e "$teardown_record" ]; then
    report first_launch_report ok
else
    report first_launch_report fail
    cat "$work/first.out" >&2
fi

# The second bring-up finds the session running, tears it down first, and
# reuses the key it minted.
if run_wrapper paced-60 >"$work/second.out" 2>"$work/second.err"; then
    report second_launch_exit ok
else
    report second_launch_exit fail
    cat "$work/second.err" >&2
fi
if [ "$(cat "$QWEN_HOME/state/web-token.key")" = "$first_key" ] &&
    grep -q ' signing_key=present ' "$work/second.out" &&
    grep -q '^prior_session=torn_down$' "$work/second.out" &&
    [ "$(wc -l <"$teardown_record")" -eq 1 ] &&
    recorded 'profile=paced-60'; then
    report running_session_torn_down_first ok
else
    report running_session_torn_down_first fail
    cat "$work/second.out" >&2
fi

# A teardown that leaves residue stops the bring-up before the launch.
if QWEN_TEST_TEARDOWN_STATUS=1 run_wrapper >"$work/residue.out" 2>"$work/residue.err"; then
    report teardown_residue_refused fail
else
    if [ "$?" -eq 1 ] && [ ! -e "$launch_record" ] &&
        grep -q 'residue' "$work/residue.err"; then
        report teardown_residue_refused ok
    else
        report teardown_residue_refused fail
    fi
fi
rm -f "$state/session.status"

# The caller's own address and the bearer mode reach the launch unchanged.
if QWEN_WEB_LAN_ADDRESS=192.168.7.7 QWEN_WEB_LAN_OPEN=0 QWEN_SERVER_PORT=9000 \
    run_wrapper >"$work/bearer.out" 2>"$work/bearer.err" &&
    recorded 'QWEN_WEB_LAN_ADDRESS=192.168.7.7' &&
    recorded 'QWEN_WEB_LAN_OPEN=0' &&
    recorded 'QWEN_SERVER_PORT=9000' &&
    grep -q ' address_source=caller ' "$work/bearer.out" &&
    grep -q ' open=0 ' "$work/bearer.out"; then
    report caller_address_and_bearer_mode ok
else
    report caller_address_and_bearer_mode fail
    cat "$work/bearer.err" >&2
fi
rm -f "$state/session.status"

# The lan-open-approved profile is the explicit opt-in; it removes the
# bearer and reports the household boundary the operator chose.
if run_wrapper lan-open-approved >"$work/open-profile.out" 2>"$work/open-profile.err" &&
    recorded 'QWEN_WEB_LAN_OPEN=1' &&
    grep -q ' security_profile=lan-open-approved ' "$work/open-profile.out" &&
    grep -qx 'LAN BOUNDARY: lan-open-approved -- every reachable peer chats, consumes model time, and fetches artifacts with no bearer' \
        "$work/open-profile.out"; then
    report open_approved_profile ok
else
    report open_approved_profile fail
    cat "$work/open-profile.err" >&2
fi
rm -f "$state/session.status"

# The lan-authenticated profile is the one-command fallback: naming it
# explicitly reaches the same bearer-required launch the bare default does.
if run_wrapper lan-authenticated low-async >"$work/auth-profile.out" 2>"$work/auth-profile.err" &&
    recorded 'QWEN_WEB_LAN_OPEN=0' &&
    grep -q ' security_profile=lan-authenticated ' "$work/auth-profile.out" &&
    grep -qx 'LAN BOUNDARY: lan-authenticated -- the Web UI bearer is required on every route' \
        "$work/auth-profile.out"; then
    report authenticated_profile_explicit ok
else
    report authenticated_profile_explicit fail
    cat "$work/auth-profile.err" >&2
fi
rm -f "$state/session.status"

# A profile argument and a conflicting QWEN_WEB_LAN_OPEN name two different
# bearer policies, so the launch refuses rather than picking one silently.
if QWEN_WEB_LAN_OPEN=1 run_wrapper lan-authenticated \
    >/dev/null 2>"$work/conflict.err"; then
    report conflicting_profile_and_override_refused fail
else
    if [ "$?" -eq 2 ] && [ ! -e "$launch_record" ] &&
        grep -q 'two different bearer policies' "$work/conflict.err"; then
        report conflicting_profile_and_override_refused ok
    else
        report conflicting_profile_and_override_refused fail
    fi
fi
rm -f "$state/session.status"

# Two security-profile names in one invocation are a usage error, the way a
# repeated performance profile is.
if run_wrapper lan-authenticated lan-open-approved \
    >/dev/null 2>"$work/two-security.err"; then
    report two_security_profiles_refused fail
else
    [ "$?" -eq 2 ] && report two_security_profiles_refused ok ||
        report two_security_profiles_refused fail
fi

# QWEN_WEB_LAN_OPEN_ALL_INTERFACES and QWEN_WEB_LAN_TRUSTED_CONNECTIONS reach
# the launch unchanged, and the flag prints loudly when it is set.
if QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 \
    QWEN_WEB_LAN_TRUSTED_CONNECTIONS=11111111-1111-1111-1111-111111111111 \
    run_wrapper lan-open-approved \
    >"$work/all-interfaces.out" 2>"$work/all-interfaces.err" &&
    recorded 'QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1' &&
    recorded 'QWEN_WEB_LAN_TRUSTED_CONNECTIONS=11111111-1111-1111-1111-111111111111' &&
    grep -q 'binds every interface' "$work/all-interfaces.err"; then
    report all_interfaces_flag_forwarded ok
else
    report all_interfaces_flag_forwarded fail
    cat "$work/all-interfaces.err" >&2
fi
rm -f "$state/session.status"

# A malformed QWEN_WEB_LAN_OPEN_ALL_INTERFACES is an argument error.
if QWEN_WEB_LAN_OPEN_ALL_INTERFACES=maybe run_wrapper \
    >/dev/null 2>"$work/bad-all-interfaces.err"; then
    report malformed_all_interfaces_refused fail
else
    if [ "$?" -eq 2 ] &&
        grep -q 'QWEN_WEB_LAN_OPEN_ALL_INTERFACES must be 0 or 1' \
            "$work/bad-all-interfaces.err"; then
        report malformed_all_interfaces_refused ok
    else
        report malformed_all_interfaces_refused fail
    fi
fi

# The caller's own parameters path replaces the deployment's.
printf '{}\n' >"$work/caller-parameters.json"
if QWEN_IMAGE_PROFILES_JSON=$work/caller-parameters.json \
    run_wrapper >"$work/caller-params.out" 2>"$work/caller-params.err" &&
    recorded "QWEN_IMAGE_PROFILES_JSON=$work/caller-parameters.json" &&
    grep -q ' image_parameters_source=caller$' "$work/caller-params.out"; then
    report caller_parameters_forwarded ok
else
    report caller_parameters_forwarded fail
    cat "$work/caller-params.err" >&2
fi
rm -f "$state/session.status"

# A launch with no active bundle, or a bundle naming no image server, serves
# the web lane alone and hands the launch no parameters path.
if QWEN_TEST_RESOLVER_STATUS=1 \
    run_wrapper >"$work/nobundle.out" 2>"$work/nobundle.err" &&
    ! grep -q '^QWEN_IMAGE_PROFILES_JSON=' "$launch_record" &&
    grep -q ' image_parameters=- image_parameters_source=none$' "$work/nobundle.out"; then
    report absent_bundle_serves_no_image_lane ok
else
    report absent_bundle_serves_no_image_lane fail
    cat "$work/nobundle.err" >&2
fi
rm -f "$state/session.status"

# A machine with no default route names no address to serve.
if QWEN_TEST_PROBE_ANSWER='' run_wrapper >"$work/noroute.out" 2>"$work/noroute.err"; then
    report absent_route_refused fail
else
    if [ "$?" -eq 1 ] && [ ! -e "$launch_record" ] &&
        grep -q 'no default route' "$work/noroute.err"; then
        report absent_route_refused ok
    else
        report absent_route_refused fail
    fi
fi

# The image parameters are a validated artifact the launch reads whole.
if QWEN_IMAGE_PROFILES_JSON=$work/absent.json \
    run_wrapper >"$work/params.out" 2>"$work/params.err"; then
    report absent_parameters_refused fail
else
    if [ "$?" -eq 1 ] && [ ! -e "$launch_record" ] &&
        grep -q 'QWEN_IMAGE_PROFILES_JSON names no readable file' "$work/params.err"; then
        report absent_parameters_refused ok
    else
        report absent_parameters_refused fail
    fi
fi

# A port with no room above it for the broker and artifact listeners, and a
# non-numeric one, are argument errors.
for bad_port in 65534 8x80 0; do
    if QWEN_SERVER_PORT=$bad_port run_wrapper >/dev/null 2>"$work/port.err"; then
        report "port_${bad_port}_refused" fail
    else
        [ "$?" -eq 2 ] && report "port_${bad_port}_refused" ok ||
            report "port_${bad_port}_refused" fail
    fi
done

# An existing key that fails validation -- empty, wrong owner, wrong mode, not
# a regular file -- refuses before the destructive teardown runs, so an
# invalid relaunch configuration leaves a working session running rather than
# tearing it down and then refusing to relaunch it.
rm -f "$state/session.status" "$teardown_record"
if run_wrapper >"$work/precheck.out" 2>"$work/precheck.err"; then
    report existing_key_precheck_setup ok
else
    report existing_key_precheck_setup fail
    cat "$work/precheck.err" >&2
fi
: >"$QWEN_HOME/state/web-token.key"
if run_wrapper >"$work/invalid-key.out" 2>"$work/invalid-key.err"; then
    report invalid_existing_key_refused_before_teardown fail
else
    if [ "$?" -eq 1 ] && [ ! -e "$teardown_record" ] &&
        grep -q 'is empty' "$work/invalid-key.err" &&
        grep -q '^state=running ' "$state/session.status"; then
        report invalid_existing_key_refused_before_teardown ok
    else
        report invalid_existing_key_refused_before_teardown fail
        cat "$work/invalid-key.err" >&2
    fi
fi
rm -f "$state/session.status"

# A symlinked key file is refused, since the key is read as a regular file.
ln -s "$work/elsewhere" "$home/linked.key"
if QWEN_WEB_TOKEN_KEY_FILE=$home/linked.key \
    run_wrapper >/dev/null 2>"$work/symlink.err"; then
    report symlinked_key_refused fail
else
    if [ "$?" -eq 1 ] && grep -q 'symlink' "$work/symlink.err"; then
        report symlinked_key_refused ok
    else
        report symlinked_key_refused fail
    fi
fi

# No boot-time path starts either LAN profile: the service starts and stops
# through the launch and teardown scripts alone, so a reboot leaves the
# machine with nothing listening. The repository ships no systemd unit or
# timer, no crontab, and no XDG autostart entry that could start one on its
# own; find over the whole tree (excluding .git) is what proves the absence
# rather than a name search that a documentation mention would false-positive.
if find "$script_directory/.." -path '*/.git' -prune -o -type f \
    \( -name '*.service' -o -name '*.timer' -o -name 'crontab' \
       -o -path '*/autostart/*' -o -path '*/cron.d/*' \) \
    -print 2>/dev/null | grep -q .; then
    report no_boot_time_launch_artifact fail
else
    report no_boot_time_launch_artifact ok
fi

if [ "$failures" -ne 0 ]; then
    printf 'qwen_lan_launch=failed failures=%s\n' "$failures"
    exit 1
fi
printf 'qwen_lan_launch=accepted\n'
