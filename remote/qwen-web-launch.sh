#!/bin/sh
set -eu

# Start the appliance in router mode against the web preset file that
# remote/build-web-presets.sh produces, on the loopback alone.
#
# A web preset section reaches a network the appliance otherwise never touches:
# a validator-gated section carries LLAMA_ARG_MCP_SERVERS_CONFIG, and the
# configured server performs searches and fetches on the model's behalf. The
# appliance binds 0.0.0.0 by default so the laptop serves the LAN, which would
# put that retrieval capability on every host of that network. This wrapper
# therefore sets QWEN_BIND_HOST=127.0.0.1 and refuses a caller who asked for any
# other listener, rather than forcing the value silently: the operator who typed
# 0.0.0.0 wants an exposure this launch declines to provide, and a refusal says
# so where a rewrite would leave the request looking honoured.
# qwen-capacity-policy.sh forces the same loopback for a preset carrying the
# unvalidated-depth marker, so the restriction survives a launch that reaches
# the policy another way.
#
# QWEN_ROUTER_MAX is 1. The 4B alone peaks at 2029 MiB of a 2048 MiB VRAM
# carve-out, so a second resident model competes for a pool one model already
# saturates. qwen-webui-control.sh forwards QWEN_ROUTER_MAX inside the tmux
# command string, so the value reaches qwen-capacity-policy.sh across the tmux
# boundary that a plain export stops at.
#
# The wrapper reports the preset's marker state and the QWEN_WEB_AUTHORIZER_READY
# setting before it launches, because those two decide what the running server
# can do: the marker says a section serves a depth no run has filled and
# decoded, and the authorizer setting says whether the generator admitted
# validator-gated rows at all.

if [ "$#" -gt 1 ]; then
    printf 'usage: %s [paced-60|low-serialized|low-async]\n' "$0" >&2
    printf 'web preset file comes from QWEN_WEB_PRESETS, default $HOME/qwen-webui-state/web-presets.ini\n' >&2
    printf 'the listener is 127.0.0.1; QWEN_BIND_HOST set to any other value refuses the launch\n' >&2
    exit 2
fi

profile=${1:-low-async}
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
launcher=$script_directory/qwen-launch.sh
state_directory=${QWEN_WEBUI_STATE_DIRECTORY:-"${HOME:?}/qwen-webui-state"}
web_presets=${QWEN_WEB_PRESETS:-$state_directory/web-presets.ini}

# The caller's own listener request is read before it is replaced, so an
# explicit LAN bind refuses rather than serving retrieval on the loopback while
# the operator believes the LAN is listening.
requested_bind_host=${QWEN_BIND_HOST:-127.0.0.1}
if [ "$requested_bind_host" != 127.0.0.1 ]; then
    printf 'web router mode serves the loopback alone, and QWEN_BIND_HOST requests %s\n' \
        "$requested_bind_host" >&2
    printf 'a web preset section reaches the network through its MCP server; unset QWEN_BIND_HOST or set it to 127.0.0.1\n' >&2
    exit 2
fi

if [ ! -r "$web_presets" ]; then
    printf 'web presets are unreadable: %s\n' "$web_presets" >&2
    printf 'generate them with remote/build-web-presets.sh\n' >&2
    exit 2
fi

if ! grep -qx '# qwen_web_presets=1' "$web_presets"; then
    printf 'preset file carries no web provenance marker: %s\n' "$web_presets" >&2
    printf 'remote/build-web-presets.sh writes `# qwen_web_presets=1`; regenerate the file\n' >&2
    exit 2
fi

# Every configuration a section names is read here, because llama-server reports
# an unreadable mcp-servers-config as a child startup failure well after the
# listener is up, where the operator reads it as a model fault.
missing_mcp_configs=0
for named_mcp_config in $(sed -n \
    's/^[[:space:]]*LLAMA_ARG_MCP_SERVERS_CONFIG[[:space:]]*=[[:space:]]*//p' \
    "$web_presets"); do
    if [ ! -r "$named_mcp_config" ]; then
        printf 'preset names an unreadable MCP configuration: %s\n' \
            "$named_mcp_config" >&2
        missing_mcp_configs=$((missing_mcp_configs + 1))
    fi
done
if [ "$missing_mcp_configs" -ne 0 ]; then
    printf 'regenerate the preset tree with remote/build-web-presets.sh\n' >&2
    exit 2
fi

if grep -qx '# qwen-web-presets: unvalidated-depth-override' "$web_presets"; then
    depth_marker_state=present
else
    depth_marker_state=absent
fi
printf 'web_launch presets=%s unvalidated_depth_marker=%s authorizer_ready=%s bind=127.0.0.1 models_max=1\n' \
    "$web_presets" "$depth_marker_state" "${QWEN_WEB_AUTHORIZER_READY:-0}"

QWEN_ROUTER=1
QWEN_ROUTER_PRESETS=$web_presets
QWEN_ROUTER_MAX=1
QWEN_BIND_HOST=127.0.0.1
export QWEN_ROUTER QWEN_ROUTER_PRESETS QWEN_ROUTER_MAX QWEN_BIND_HOST

exec "$launcher" "$profile"
