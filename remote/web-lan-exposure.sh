#!/bin/sh
# The listener policy the web and image launchers share, sourced rather than
# executed so the exports it decides reach the launcher's own environment.
#
# `qwen-web-launch.sh` and `qwen-image-launch.sh` serve the loopback by default
# and refuse a caller who asked for any other listener, because a web preset
# section reaches the network through its MCP server and an image section
# spawns a device runtime through its own. `QWEN_WEB_LAN=1` is the operator's
# explicit decision to move that boundary, and this file states what the
# decision costs: the router, the approval broker, and the artifact listener
# all reach the named address, and the Web UI bearer becomes the credential
# every one of them requires. The single-use grant and the approval dialog stay
# the whole execution gate; the exposure changes who can reach the dialog and
# never what an approval buys.
#
# Six conditions hold before the exposure is admitted, and each one is a
# refusal rather than a warning.
#
# QWEN_WEB_LAN_ADDRESS names an IPv4 literal that a reader reaches. The broker
# and the artifact listener compare a request's Host header against a literal
# set, which is what closes DNS rebinding against a bound address, so a name
# resolving through the resolver has no place in that comparison and the
# wildcard names no address to compare against. QWEN_BIND_HOST is the router's
# own listener and may be that literal or the wildcard; every derived origin
# and Host rule reads the literal.
#
# The Web UI API key is required whole, at mode 0600 or tighter, owned by the
# serving user and nonempty, because the bearer is what stands between a LAN
# reader and the router's routes, the broker's signing routes, and the
# artifact listener. `qwen-webui-session.sh` mints one where the file is
# absent, and a launch that mints its credential in the same breath it exposes
# the listener leaves the operator reading a key out of a state directory after
# the socket is already up; requiring the file first inverts that order.
#
# The two research overrides stay on the loopback. `qwen-capacity-policy.sh`
# forces 127.0.0.1 for a preset carrying the quarantine override or the
# unvalidated-depth marker, so an exposure combined with either would print one
# address and bind another. Both combinations are refused here instead: a
# checkpoint with a recorded device failure stays off the LAN, and a section
# serving a depth no run has filled and decoded is validated rather than
# exposed.

refuse_web_lan_exposure() {
    printf 'the LAN exposure opt-in %s\n' "$1" >&2
    printf 'QWEN_WEB_LAN=1 requires QWEN_WEB_LAN_ADDRESS naming a routable IPv4 literal, an existing Web UI API key at mode 0600, and a preset carrying neither research override\n' >&2
    exit 2
}

# Return success where the argument is an IPv4 literal that departs from the
# loopback default and names an address a reader reaches. `exposed_host` in
# authorize-broker.py and image-service.py applies the identical rule, so one
# address passes the launcher and both listeners; the second loopback address
# 127.0.0.2 is admitted under it, which puts a served page at a non-loopback
# origin in reach of a test on a host holding no LAN.
web_lan_address_is_literal() {
    case $1 in
        '' | *[!0-9.]* | 0.0.0.0 | 127.0.0.1) return 1 ;;
    esac
    printf '%s' "$1" | awk -F. '
        NF != 4 { exit 1 }
        {
            for (octet = 1; octet <= 4; octet++) {
                if ($octet == "" || length($octet) > 3) exit 1
                if ($octet + 0 > 255) exit 1
            }
        }
    '
}

# Validate the opt-in against the preset and the API key file, then export the
# three variables the launcher, qwen-webui-control.sh, and the session read.
# The caller passes the preset path and the API key path it resolved itself.
admit_web_lan_exposure() {
    web_lan_presets=$1
    web_lan_api_key=$2
    if ! web_lan_address_is_literal "${QWEN_WEB_LAN_ADDRESS:-}"; then
        refuse_web_lan_exposure \
            "names address ${QWEN_WEB_LAN_ADDRESS:-<unset>}, which is not a routable IPv4 literal"
    fi
    web_lan_bind_host=${QWEN_BIND_HOST:-$QWEN_WEB_LAN_ADDRESS}
    if [ "$web_lan_bind_host" != "$QWEN_WEB_LAN_ADDRESS" ] &&
        [ "$web_lan_bind_host" != 0.0.0.0 ]; then
        refuse_web_lan_exposure \
            "binds $web_lan_bind_host where the exposure names $QWEN_WEB_LAN_ADDRESS; QWEN_BIND_HOST is that literal or 0.0.0.0"
    fi
    case ${QWEN_REQUIRE_API_KEY:-1} in
        1) ;;
        *)
            refuse_web_lan_exposure \
                "serves an authenticated listener, and QWEN_REQUIRE_API_KEY names ${QWEN_REQUIRE_API_KEY}"
            ;;
    esac
    if [ -L "$web_lan_api_key" ] || [ ! -f "$web_lan_api_key" ]; then
        refuse_web_lan_exposure "finds no Web UI API key file at $web_lan_api_key"
    fi
    if [ ! -s "$web_lan_api_key" ]; then
        refuse_web_lan_exposure "finds an empty Web UI API key file at $web_lan_api_key"
    fi
    web_lan_key_owner=$(stat -c %u "$web_lan_api_key" 2>/dev/null || echo unknown)
    if [ "$web_lan_key_owner" != "$(id -u)" ]; then
        refuse_web_lan_exposure \
            "finds the Web UI API key owned by uid $web_lan_key_owner rather than $(id -u)"
    fi
    web_lan_key_mode=$(stat -c %a "$web_lan_api_key" 2>/dev/null || echo unknown)
    case $web_lan_key_mode in
        400 | 600) ;;
        *)
            refuse_web_lan_exposure \
                "finds the Web UI API key at mode $web_lan_key_mode rather than 0600"
            ;;
    esac
    if grep -qx '# qwen-web-presets: unvalidated-depth-override' "$web_lan_presets"; then
        refuse_web_lan_exposure \
            "meets a preset serving a depth no run has filled and decoded; validate the depth or serve it on the loopback"
    fi
    if grep -qx '# qwen_router_include_quarantine=1' "$web_lan_presets" ||
        [ "${QWEN_ROUTER_INCLUDE_QUARANTINE:-0}" = 1 ]; then
        refuse_web_lan_exposure \
            "meets the quarantine research override; a checkpoint with a recorded device failure serves the loopback"
    fi
    QWEN_BIND_HOST=$web_lan_bind_host
    QWEN_WEB_LAN=1
    export QWEN_BIND_HOST QWEN_WEB_LAN QWEN_WEB_LAN_ADDRESS
}
