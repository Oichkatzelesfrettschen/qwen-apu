#!/bin/sh
set -eu

# Bring the appliance up on the operator's own LAN in one command, and print
# the one address a browser on that network opens.
#
# qwen-launch.sh takes the LAN exposure as a set of environment variables:
# the port, the routable address, the opt-in that removes the bearer, the
# signing key the approval broker requires whole before anything starts, the
# MCP server and provider the web section runs, and the validated parameter
# file the image service runs a job under. Each one is a decision the launch
# chain refuses to guess, so an operator typing them at a prompt reproduces a
# nine-line environment on every relaunch and a line missed on one relaunch
# serves a different appliance than the last. This wrapper states those
# decisions once, derives the two that this machine answers for itself, and
# hands the whole set to qwen-launch.sh, which applies every rule
# web-lan-exposure.sh holds exactly as it does for a hand-typed launch.
#
# The address is read from the kernel's own route rather than from a value
# an operator memorized: `ip -4 route get` names the source address the
# default route leaves through, which is the address a DHCP lease assigned
# this link and the one a LAN peer reaches. The name the launch prints beside
# it comes from avahi through web-lan-exposure.sh, so the printed page URL is
# the `<hostname>.local` form a lease never moves. QWEN_WEB_LAN_ADDRESS set
# by the caller replaces the derivation.
#
# The image parameters are read from the active deployment rather than from
# a path of this script's own. build-router-presets.sh writes the path into
# the image server's MCP configuration, the bundle binds that configuration
# by digest, and image-launch-lib.sh requires the launch to serve the same
# path the child reads; so the wrapper resolves the bundle, reads every MCP
# configuration its preset names through read-image-mcp-server.py, and takes
# the path the image server carries. A bundle whose preset names no image
# server serves the web lane alone, and QWEN_IMAGE_PROFILES_JSON set by the
# caller replaces the derivation.
#
# The signing key is the HMAC secret authorize-broker.py signs grants with,
# which is a different credential from the Web UI API key the bearer mode
# reads out of the state directory. It belongs to this appliance rather than
# to any session, so the wrapper mints it on the first bring-up under umask
# 077 and reuses the file on every later one; the file stays outside the
# repository and its contents are never printed.
#
# QWEN_WEB_LAN_OPEN defaults to 1 here because the LAN bring-up is the
# operator's stated intent to serve peers on the network: every peer can
# chat, approve a search, and approve a generation, and the approval dialog,
# the single-use grant, the closed Host set, and each tool's schema remain
# the execution gate. QWEN_WEB_LAN_OPEN=0 serves the same listeners with the
# Web UI bearer required on each, and qwen-launch.sh then prints the page
# link carrying the key when its stdout is a terminal.
#
# A session already running is torn down first, because qwen-launch.sh
# refuses a second session and the operator running this script wants the
# appliance up on the configuration the script states, not the one a prior
# launch left. The teardown proves absence and exits non-zero on residue, and
# that residue refuses the launch rather than starting a second server beside
# it.
#
# qwen-teardown.sh ends what this script starts.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [paced-60|low-serialized|low-async]\n' "$0" >&2
    printf 'QWEN_SERVER_PORT names the router port, default 42069; the broker and artifact listeners take the next two\n' >&2
    printf 'QWEN_WEB_LAN_ADDRESS names the IPv4 literal to serve; the default is the source address of the default route\n' >&2
    printf 'QWEN_WEB_LAN_OPEN=0 requires the Web UI bearer on every listener; the default 1 serves every peer without one\n' >&2
    printf 'QWEN_WEB_TOKEN_KEY_FILE names the broker signing key, default $HOME/qwen-web-token.key, minted when absent\n' >&2
    printf 'QWEN_IMAGE_PROFILES_JSON names the validated image parameters; the default is the path the active deployment image server carries\n' >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
profile=${1:-low-async}
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
server_port=${QWEN_SERVER_PORT:-42069}
signing_key_file=${QWEN_WEB_TOKEN_KEY_FILE:-"$HOME/qwen-web-token.key"}
web_mcp_server=${QWEN_WEB_MCP_SERVER:-"$script_directory/web-mcp/server.py"}
web_provider=${QWEN_WEB_PROVIDER:-searxng}

case $server_port in
    '' | *[!0-9]* | 0*)
        printf 'QWEN_SERVER_PORT is a positive decimal port: %s\n' "$server_port" >&2
        exit 2
        ;;
esac
if [ "$server_port" -lt 1 ] || [ "$server_port" -gt 65533 ]; then
    printf 'QWEN_SERVER_PORT leaves room for the broker and artifact ports above it: %s\n' \
        "$server_port" >&2
    exit 2
fi

case ${QWEN_WEB_LAN_OPEN:-1} in
    0 | 1) ;;
    *)
        printf 'QWEN_WEB_LAN_OPEN must be 0 or 1: %s\n' "$QWEN_WEB_LAN_OPEN" >&2
        exit 2
        ;;
esac
lan_open=${QWEN_WEB_LAN_OPEN:-1}

# Print the source address of the default route. QWEN_LAN_ADDRESS_PROBE names
# another command so a test states the answer instead of reading the host it
# runs on.
default_route_address() {
    if [ -n "${QWEN_LAN_ADDRESS_PROBE:-}" ]; then
        $QWEN_LAN_ADDRESS_PROBE
        return
    fi
    ip -4 route get 1.1.1.1 2>/dev/null | awk '
        {
            for (field = 1; field <= NF; field++) {
                if ($field == "src") {
                    print $(field + 1)
                    exit
                }
            }
        }
    '
}

if [ -n "${QWEN_WEB_LAN_ADDRESS:-}" ]; then
    lan_address=$QWEN_WEB_LAN_ADDRESS
    lan_address_source=caller
else
    lan_address=$(default_route_address || true)
    lan_address_source=default-route
    if [ -z "$lan_address" ]; then
        printf 'this machine has no default route to derive a LAN address from; set QWEN_WEB_LAN_ADDRESS to the IPv4 literal to serve\n' >&2
        exit 1
    fi
fi

# Print the parameters path the active deployment's image server carries, or
# nothing where its preset names no image server or no bundle is active.
image_parameters_from_active_deployment() {
    deployment_report=$("$script_directory/resolve-active-deployment.sh" 2>/dev/null) ||
        return 0
    router_presets=$(printf '%s\n' "$deployment_report" |
        sed -n 's/^active_deployment_router_presets=//p')
    [ -f "$router_presets" ] || return 0
    awk '
        {
            separator = index($0, "=")
            if (separator == 0) next
            key = substr($0, 1, separator - 1)
            value = substr($0, separator + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == "LLAMA_ARG_MCP_SERVERS_CONFIG") print value
        }
    ' "$router_presets" | while IFS= read -r mcp_configuration; do
        image_server_report=$("$script_directory/read-image-mcp-server.py" \
            "$mcp_configuration" 2>/dev/null) || continue
        case $image_server_report in
            *image_server=present*)
                printf '%s\n' "$image_server_report" |
                    sed -n 's/^QWEN_IMAGE_PROFILES_JSON=//p'
                break
                ;;
        esac
    done
}

if [ -n "${QWEN_IMAGE_PROFILES_JSON:-}" ]; then
    image_profiles_json=$QWEN_IMAGE_PROFILES_JSON
    image_parameters_source=caller
else
    image_profiles_json=$(image_parameters_from_active_deployment)
    if [ -n "$image_profiles_json" ]; then
        image_parameters_source=active-deployment
    else
        image_parameters_source=none
    fi
fi
if [ -n "$image_profiles_json" ] && [ ! -r "$image_profiles_json" ]; then
    printf 'QWEN_IMAGE_PROFILES_JSON names no readable file: %s\n' \
        "$image_profiles_json" >&2
    printf 'remote/admit-image-router.sh writes image-parameters.json into its output directory, and the deployment image server names that file\n' >&2
    exit 1
fi

if [ ! -x "$script_directory/qwen-launch.sh" ] ||
    [ ! -x "$script_directory/qwen-teardown.sh" ]; then
    printf 'qwen-launch.sh and qwen-teardown.sh are required beside %s\n' \
        "$script_directory" >&2
    exit 1
fi

# Mint the broker signing key on the first bring-up. The umask applies to the
# whole subshell, so the file exists at mode 0600 from its first byte, and
# 32 random bytes as 64 hex characters are the key.
if [ -L "$signing_key_file" ]; then
    printf 'QWEN_WEB_TOKEN_KEY_FILE names a symlink, and the key is a regular file: %s\n' \
        "$signing_key_file" >&2
    exit 1
fi
if [ ! -e "$signing_key_file" ]; then
    (
        umask 077
        od -An -tx1 -N32 /dev/urandom | tr -d ' \n' >"$signing_key_file"
        printf '\n' >>"$signing_key_file"
    )
    signing_key_state=minted
else
    signing_key_state=present
fi

# A running session ends here before the new one starts. The status line is
# the session's own record and the teardown compares it with the live
# process table, so a stale record with nothing behind it is cleaned rather
# than refused.
session_status=$state_directory/session.status
if [ -f "$session_status" ] && grep -q '^state=running' "$session_status"; then
    if "$script_directory/qwen-teardown.sh"; then
        printf 'prior_session=torn_down\n'
    else
        printf 'the prior session left residue the teardown could not remove; the launch stops here\n' >&2
        exit 1
    fi
else
    printf 'prior_session=none\n'
fi

printf 'lan_launch port=%s address=%s address_source=%s open=%s signing_key=%s provider=%s image_parameters=%s image_parameters_source=%s\n' \
    "$server_port" "$lan_address" "$lan_address_source" "$lan_open" \
    "$signing_key_state" "$web_provider" "${image_profiles_json:--}" \
    "$image_parameters_source"

# An empty parameters path stays out of the environment, since the launch
# reads the variable's presence as the lane's own claim.
if [ -n "$image_profiles_json" ]; then
    QWEN_IMAGE_PROFILES_JSON=$image_profiles_json
    export QWEN_IMAGE_PROFILES_JSON
fi
QWEN_SERVER_PORT=$server_port \
QWEN_WEB_LAN=1 \
QWEN_WEB_LAN_ADDRESS=$lan_address \
QWEN_WEB_LAN_OPEN=$lan_open \
QWEN_BIND_HOST=${QWEN_BIND_HOST:-0.0.0.0} \
QWEN_ROUTER=1 \
QWEN_WEB_AUTHORIZER_READY=1 \
QWEN_WEB_TOKEN_KEY_FILE=$signing_key_file \
QWEN_WEB_MCP_SERVER=$web_mcp_server \
QWEN_WEB_PROVIDER=$web_provider \
    "$script_directory/qwen-launch.sh" "$profile"

# The launch printed the addresses it admitted; the session record carries
# the name avahi answered with, which is the address to bookmark.
lan_name=""
if [ -f "$session_status" ]; then
    lan_name=$(sed -n 's/^state=running.* lan_name=\([^ ]*\).*/\1/p' "$session_status" | head -n 1)
fi
if [ -n "$lan_name" ]; then
    printf 'open http://%s:%s/ from any machine on this network\n' \
        "$lan_name" "$server_port"
fi
printf 'or http://%s:%s/ by address while this lease holds\n' \
    "$lan_address" "$server_port"
printf 'end it with %s/qwen-teardown.sh\n' "$script_directory"
