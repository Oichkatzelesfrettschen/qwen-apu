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
# QWEN_WEB_LAN_NAME adds one mDNS name to that admitted set, and the set stays
# closed to exactly one lowercase label under `.local`. A DHCP lease moves the
# literal, so the name is what an operator bookmarks; avahi advertises
# `<label>.local` on the link and a browser resolves that suffix by multicast
# to the hosts sharing the link rather than through a recursive resolver, so
# the admitted form is what keeps a name an attacker controls in public DNS
# from ever resolving to this appliance. A bare hostname, a public domain, a
# name carrying more than one label under `.local`, an uppercase letter, and a
# trailing dot are each refused by name rather than reshaped: any of them
# would register in the ordinary resolver, and a name that resolves there
# reopens the rebinding closure the literal address exists to hold shut. The
# default is this machine's own `hostname -s` lowercased under `.local` where
# avahi-daemon runs, and an explicit empty value serves the literal alone.
#
# The Web UI API key is required whole, at mode 0600 or tighter, owned by the
# serving user and nonempty, because the bearer is what stands between a LAN
# reader and the router's routes, the broker's signing routes, and the
# artifact listener. `qwen-webui-session.sh` mints one where the file is
# absent, and a launch that mints its credential in the same breath it exposes
# the listener leaves the operator reading a key out of a state directory after
# the socket is already up; requiring the file first inverts that order.
#
# QWEN_WEB_LAN_OPEN=1 is the second explicit decision and it removes that
# bearer. The router serves without a key, the broker signs a grant for a
# request presenting the session secret alone, and the artifact listener reads
# an artifact for any admitted Host. Every LAN peer that reaches the page can
# then chat, approve a search, and approve a generation. What the opt-in leaves
# standing is every gate that is not the bearer: the closed Host set, the
# per-launch session secret, the Origin allowlist, the single-use grant, the
# schema each wrapped tool enforces, and the one human approval per
# network-reaching and device-reaching call. It requires QWEN_WEB_LAN=1,
# because a listener the operator never exposed has no bearer to remove, and
# it meets both research-override refusals below on the same terms the
# exposure does.
#
# The two research overrides stay on the loopback. `qwen-capacity-policy.sh`
# forces 127.0.0.1 for a preset carrying the quarantine override or the
# unvalidated-depth marker, so an exposure combined with either would print one
# address and bind another. Both combinations are refused here instead: a
# checkpoint with a recorded device failure stays off the LAN, and a section
# serving a depth no run has filled and decoded is validated rather than
# exposed.
#
# The bind host defaults to the exposure literal alone, so the router, the
# broker, and the artifact listener answer on the one interface that address
# lives on. `QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1` is a third explicit decision
# that widens the bind to every interface; naming it is what admits
# `QWEN_BIND_HOST=0.0.0.0`, and the launcher prints the widened bind loudly
# rather than folding it into the ordinary exposure line.
#
# The interface carrying the exposure literal is read through `ip -j addr`
# and joined to its NetworkManager connection through
# `nmcli -t -f UUID,NAME,DEVICE connection show --active`, so the exposure
# line records the interface index, name, MAC, prefix length, and connection
# UUID and name beside the literal a peer reaches. `QWEN_WEB_LAN_OPEN=1`
# removes the bearer, so an operator who plugs the exposure literal onto an
# untrusted link -- a hotel network, a phone hotspot -- would otherwise open
# every route to it with nothing standing between a reader and the page.
# `QWEN_WEB_LAN_TRUSTED_CONNECTIONS` closes that: a colon-separated list of
# NetworkManager connection UUIDs an operator declares trusted. A declared
# list gates both modes, so a bearer-protected launch on an interface outside
# it still refuses; an absent list refuses the open opt-in alone, since the
# bearer is what makes an authenticated launch on an undeclared connection
# survive the same exposure.

refuse_web_lan_exposure() {
    printf 'the LAN exposure opt-in %s\n' "$1" >&2
    printf 'QWEN_WEB_LAN=1 requires QWEN_WEB_LAN_ADDRESS naming a routable IPv4 literal, an existing Web UI API key at mode 0600, and a preset carrying neither research override\n' >&2
    exit 2
}

# Read QWEN_WEB_LAN and QWEN_WEB_LAN_OPEN as the two decisions they are, ahead
# of the API-key requirement each launcher derives from them. The open opt-in
# names the exposure it opens, so an operator who set it against a loopback
# launch learns that here rather than serving an authenticated loopback and
# believing the LAN reads it.
resolve_web_lan_mode() {
    case ${QWEN_WEB_LAN:-0} in
        0 | 1) ;;
        *)
            printf 'QWEN_WEB_LAN must be 0 or 1: %s\n' "$QWEN_WEB_LAN" >&2
            exit 2
            ;;
    esac
    case ${QWEN_WEB_LAN_OPEN:-0} in
        0 | 1) ;;
        *)
            printf 'QWEN_WEB_LAN_OPEN must be 0 or 1: %s\n' \
                "$QWEN_WEB_LAN_OPEN" >&2
            exit 2
            ;;
    esac
    if [ "${QWEN_WEB_LAN_OPEN:-0}" = 1 ] && [ "${QWEN_WEB_LAN:-0}" != 1 ]; then
        printf 'QWEN_WEB_LAN_OPEN=1 removes the bearer from a LAN listener, and this launch exposes none\n' >&2
        printf 'set QWEN_WEB_LAN=1 with QWEN_WEB_LAN_ADDRESS to expose the lane, or leave QWEN_WEB_LAN_OPEN unset\n' >&2
        exit 2
    fi
    QWEN_WEB_LAN_OPEN=${QWEN_WEB_LAN_OPEN:-0}
    export QWEN_WEB_LAN_OPEN
}

# Return success where the argument is exactly one lowercase mDNS label under
# `.local`. Every other DNS-resolvable form is refused by name here rather
# than reshaped: a bare hostname, a public domain, a second label under
# `.local`, an uppercase letter, and a trailing dot each name something the
# ordinary resolver can answer, and admitting any of them reopens the DNS
# rebinding closure the literal address and this restriction together hold
# shut. The label follows RFC 1123: one to 63 characters of the lowercase
# letter, digit, and hyphen set, with no leading or trailing hyphen.
web_lan_name_is_valid() {
    case $1 in
        *.local) ;;
        *) return 1 ;;
    esac
    web_lan_label=${1%.local}
    case $web_lan_label in
        '' | *[!a-z0-9-]* | -* | *-) return 1 ;;
    esac
    [ "${#web_lan_label}" -le 63 ]
}

# Print the mDNS name this machine advertises, or nothing where it advertises
# none. `hostname -s` is the short form, so a machine already named `foo.local`
# yields `foo.local` rather than `foo.local.local`. The probe is a command
# rather than a file test because avahi publishes from a running daemon;
# QWEN_WEB_LAN_AVAHI_PROBE names another command so a test states the answer
# instead of reading the host it runs on.
web_lan_default_name() {
    web_lan_avahi_probe=${QWEN_WEB_LAN_AVAHI_PROBE:-}
    if [ -n "$web_lan_avahi_probe" ]; then
        $web_lan_avahi_probe >/dev/null 2>&1 || return 0
    elif command -v systemctl >/dev/null 2>&1; then
        systemctl is-active --quiet avahi-daemon 2>/dev/null || return 0
    elif command -v pgrep >/dev/null 2>&1; then
        pgrep -x avahi-daemon >/dev/null 2>&1 || return 0
    else
        return 0
    fi
    web_lan_short_hostname=$(hostname -s 2>/dev/null || hostname 2>/dev/null) ||
        return 0
    web_lan_short_hostname=${web_lan_short_hostname%%.*}
    web_lan_short_hostname=$(printf '%s' "$web_lan_short_hostname" |
        tr '[:upper:]' '[:lower:]')
    [ -n "$web_lan_short_hostname" ] || return 0
    printf '%s.local' "$web_lan_short_hostname"
}

# Return success where the argument is an IPv4 literal that departs from the
# loopback default and names an address a reader reaches. `exposed_host` in
# authorize-broker.py and image-service.py applies the identical rule, so one
# address passes the launcher and both listeners; the second loopback address
# 127.0.0.2 is admitted under it, which puts a served page at a non-loopback
# origin in reach of a test on a host holding no LAN. The IPv4-only character
# class is what refuses ::1 here; an editor adding IPv6 support restores that
# refusal explicitly, the way `exposed_host` states it against LOOPBACK_HOSTS.
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

# Print the interface identity carrying ADDRESS as key=value lines, or return
# failure where no interface holds it. `ip -j addr` reports one JSON object
# per interface with the link's own MAC under "address" and each configured
# address under "addr_info"; `nmcli -t -f UUID,NAME,DEVICE` binds that
# interface name to the NetworkManager connection carrying it, since the
# trusted-connection list an operator declares names the connection rather
# than the transient interface. `QWEN_LAN_INTERFACE_PROBE` and
# `QWEN_LAN_CONNECTION_PROBE` name replacement commands so a test states the
# answer instead of reading the host it runs on; an unmatched device or a
# non-NetworkManager host prints empty nm_uuid and nm_name fields rather than
# failing, since a declared trusted list is what turns that gap into a
# refusal.
web_lan_interface_report() {
    web_lan_report_address=$1
    web_lan_interface_probe=${QWEN_LAN_INTERFACE_PROBE:-'ip -j addr'}
    web_lan_connection_probe=${QWEN_LAN_CONNECTION_PROBE:-'nmcli -t -f UUID,NAME,DEVICE connection show --active'}
    web_lan_interface_json=$($web_lan_interface_probe 2>/dev/null) || return 1
    web_lan_connection_lines=$($web_lan_connection_probe 2>/dev/null) || \
        web_lan_connection_lines=''
    python3 -c "$web_lan_interface_report_python" \
        "$web_lan_report_address" "$web_lan_connection_lines" \
        "$web_lan_interface_json"
}

web_lan_interface_report_python=$(cat <<'PYEOF'
import json
import sys

address = sys.argv[1]
connection_lines = sys.argv[2]
raw_json = sys.argv[3]

try:
    interfaces = json.loads(raw_json)
except ValueError:
    sys.exit(1)

match = None
prefixlen = ""
for interface in interfaces:
    for entry in interface.get("addr_info", []):
        if entry.get("family") == "inet" and entry.get("local") == address:
            match = interface
            prefixlen = str(entry.get("prefixlen", ""))
            break
    if match is not None:
        break

if match is None:
    sys.exit(1)

ifindex = match.get("ifindex", "")
ifname = match.get("ifname", "")
mac = match.get("address", "")

nm_uuid = ""
nm_name = ""
for line in connection_lines.splitlines():
    fields = line.split(":")
    if len(fields) < 3:
        continue
    device = fields[-1]
    uuid = fields[0]
    name = ":".join(fields[1:-1])
    if device == ifname:
        nm_uuid = uuid
        nm_name = name
        break

print("ifindex=%s" % ifindex)
print("ifname=%s" % ifname)
print("mac=%s" % mac)
print("prefixlen=%s" % prefixlen)
print("nm_uuid=%s" % nm_uuid)
# The session's status file is space-delimited key=value fields, and a
# NetworkManager connection name commonly carries a space of its own
# ("Wired connection 1"), which would split into extra fields under that
# convention and read as several keys rather than one. Run-fold every space
# in the name to an underscore here, at the one place that reads it, so
# every consumer of QWEN_WEB_LAN_NM_NAME and the recorded lan_interface line
# reads the identical single token.
print("nm_name=%s" % "_".join(nm_name.split()))
PYEOF
)

# Return success where CANDIDATE names one entry of a colon-separated list.
web_lan_connection_is_trusted() {
    case ":$2:" in
        *":$1:"*) [ -n "$1" ] ;;
        *) return 1 ;;
    esac
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
    case ${QWEN_WEB_LAN_OPEN_ALL_INTERFACES:-0} in
        0 | 1) ;;
        *)
            refuse_web_lan_exposure \
                "reads QWEN_WEB_LAN_OPEN_ALL_INTERFACES=${QWEN_WEB_LAN_OPEN_ALL_INTERFACES}, which must be 0 or 1"
            ;;
    esac
    web_lan_open_all_interfaces=${QWEN_WEB_LAN_OPEN_ALL_INTERFACES:-0}
    web_lan_bind_host=${QWEN_BIND_HOST:-$QWEN_WEB_LAN_ADDRESS}
    if [ "$web_lan_bind_host" = 0.0.0.0 ]; then
        if [ "$web_lan_open_all_interfaces" != 1 ]; then
            refuse_web_lan_exposure \
                "binds 0.0.0.0, and only QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 admits every interface rather than $QWEN_WEB_LAN_ADDRESS alone"
        fi
        printf 'QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1 binds every interface; the ordinary exposure binds %s alone\n' \
            "$QWEN_WEB_LAN_ADDRESS" >&2
    elif [ "$web_lan_bind_host" != "$QWEN_WEB_LAN_ADDRESS" ]; then
        refuse_web_lan_exposure \
            "binds $web_lan_bind_host where the exposure names $QWEN_WEB_LAN_ADDRESS; QWEN_BIND_HOST is that literal, unset, or 0.0.0.0 under QWEN_WEB_LAN_OPEN_ALL_INTERFACES=1"
    fi
    # A second loopback-range literal (127.0.0.2 and beyond) is the documented
    # test convenience above, not a link this machine plugs into: the whole
    # 127.0.0.0/8 block routes through `lo` without a per-address interface,
    # so no `ip -j addr` row names one and no NetworkManager connection
    # carries it. Interface identity and the trusted-connection gate apply to
    # a routable literal alone.
    case $QWEN_WEB_LAN_ADDRESS in
        127.*) web_lan_loopback_range=1 ;;
        *) web_lan_loopback_range=0 ;;
    esac
    if [ "$web_lan_loopback_range" = 1 ]; then
        web_lan_ifindex=''
        web_lan_ifname=loopback-range
        web_lan_mac=''
        web_lan_prefixlen=''
        web_lan_nm_uuid=''
        web_lan_nm_name=''
    else
        if ! web_lan_interface_report_output=$(web_lan_interface_report "$QWEN_WEB_LAN_ADDRESS"); then
            refuse_web_lan_exposure \
                "finds no interface carrying $QWEN_WEB_LAN_ADDRESS through ip -j addr"
        fi
        web_lan_ifindex=$(printf '%s\n' "$web_lan_interface_report_output" | sed -n 's/^ifindex=//p')
        web_lan_ifname=$(printf '%s\n' "$web_lan_interface_report_output" | sed -n 's/^ifname=//p')
        web_lan_mac=$(printf '%s\n' "$web_lan_interface_report_output" | sed -n 's/^mac=//p')
        web_lan_prefixlen=$(printf '%s\n' "$web_lan_interface_report_output" | sed -n 's/^prefixlen=//p')
        web_lan_nm_uuid=$(printf '%s\n' "$web_lan_interface_report_output" | sed -n 's/^nm_uuid=//p')
        web_lan_nm_name=$(printf '%s\n' "$web_lan_interface_report_output" | sed -n 's/^nm_name=//p')
        # A declared trusted list gates both modes; an absent one refuses the
        # open opt-in alone, since the bearer is what an authenticated launch
        # on an undeclared connection still stands behind.
        web_lan_trusted=${QWEN_WEB_LAN_TRUSTED_CONNECTIONS:-}
        if [ -n "$web_lan_trusted" ]; then
            if ! web_lan_connection_is_trusted "$web_lan_nm_uuid" "$web_lan_trusted"; then
                refuse_web_lan_exposure \
                    "binds an interface (${web_lan_ifname:-<unresolved>}) whose NetworkManager connection (${web_lan_nm_uuid:-<none>}) is outside QWEN_WEB_LAN_TRUSTED_CONNECTIONS"
            fi
        elif [ "${QWEN_WEB_LAN_OPEN:-0}" = 1 ]; then
            refuse_web_lan_exposure \
                "removes the bearer with no QWEN_WEB_LAN_TRUSTED_CONNECTIONS declared; run nmcli -t -f UUID,NAME connection show --active and list this interface's connection UUID in a colon-separated QWEN_WEB_LAN_TRUSTED_CONNECTIONS to open it"
        fi
    fi
    # The open opt-in and the bearer are the two states of one credential
    # decision, so each requires QWEN_REQUIRE_API_KEY to carry the value the
    # launcher derived from it: an exposure serving a bearer with the key
    # switched off, or an open exposure with it switched on, would print one
    # policy and serve the other.
    if [ "${QWEN_WEB_LAN_OPEN:-0}" = 1 ]; then
        case ${QWEN_REQUIRE_API_KEY:-0} in
            0) ;;
            *)
                refuse_web_lan_exposure \
                    "removes the bearer, and QWEN_REQUIRE_API_KEY names ${QWEN_REQUIRE_API_KEY}"
                ;;
        esac
    else
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
    fi
    # A value the caller set, empty included, is the caller's answer; an unset
    # variable is the question this machine answers from avahi.
    if [ "${QWEN_WEB_LAN_NAME+set}" = set ]; then
        web_lan_name=$QWEN_WEB_LAN_NAME
    else
        web_lan_name=$(web_lan_default_name)
    fi
    if [ -n "$web_lan_name" ] && ! web_lan_name_is_valid "$web_lan_name"; then
        refuse_web_lan_exposure \
            "names host $web_lan_name, which is not a hostname a browser resolves on the link; the admitted set holds exactly one lowercase mDNS label under .local"
    fi
    # web_lan_name_is_valid already requires the lowercase form, so this
    # string is the one spelling authorize-broker.py's and image-service.py's
    # own `exposed_name` admit and the one every Host and Origin comparison
    # reads; an uppercase caller value is refused above rather than reshaped
    # here, since silently downcasing it would configure an allowlist entry
    # the operator never typed.
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
    QWEN_WEB_LAN_NAME=$web_lan_name
    QWEN_WEB_LAN_OPEN=${QWEN_WEB_LAN_OPEN:-0}
    QWEN_WEB_LAN_OPEN_ALL_INTERFACES=$web_lan_open_all_interfaces
    QWEN_WEB_LAN_IFINDEX=$web_lan_ifindex
    QWEN_WEB_LAN_IFNAME=$web_lan_ifname
    QWEN_WEB_LAN_MAC=$web_lan_mac
    QWEN_WEB_LAN_PREFIXLEN=$web_lan_prefixlen
    QWEN_WEB_LAN_NM_UUID=$web_lan_nm_uuid
    QWEN_WEB_LAN_NM_NAME=$web_lan_nm_name
    export QWEN_BIND_HOST QWEN_WEB_LAN QWEN_WEB_LAN_ADDRESS QWEN_WEB_LAN_NAME \
        QWEN_WEB_LAN_OPEN QWEN_WEB_LAN_OPEN_ALL_INTERFACES \
        QWEN_WEB_LAN_IFINDEX QWEN_WEB_LAN_IFNAME QWEN_WEB_LAN_MAC \
        QWEN_WEB_LAN_PREFIXLEN QWEN_WEB_LAN_NM_UUID QWEN_WEB_LAN_NM_NAME
}
