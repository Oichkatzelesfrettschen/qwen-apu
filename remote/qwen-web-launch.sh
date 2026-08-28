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
#
# The wrapper reads every path its sections name, because a preset persists
# across the generation that resolved it: an MCP configuration llama-server
# cannot read fails the child at startup, and a projector that has moved since
# generation leaves the vision child answering an image request from nothing.
#
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

# Every artifact a section names is read here, because llama-server reports an
# unreadable mcp-servers-config as a child startup failure well after the
# listener is up, and reads a section's projector only when a request selects
# that child, so an absent projector answers an image request from nothing while
# the listener has already reported ready. A preset persists across the
# generation that resolved both paths, so a file deleted or moved since then is
# found before the launch rather than by the request that needs it.
#
# The named paths reach the loop one line at a time through a file rather than
# through command substitution, which field-splits a path holding a space into
# several unreadable fragments; $HOME, QWEN_WEBUI_STATE_DIRECTORY, and
# QWEN_WEB_PRESETS each place one in the generated tree. The loop reads from a
# redirection rather than a pipeline so its count survives the loop, since a
# pipeline runs the body in a subshell and leaves the count at zero.
named_artifact_list=$(mktemp)
trap 'rm -f -- "$named_artifact_list"' EXIT HUP INT TERM
missing_named_artifacts=0
count_missing_named_artifacts() {
    artifact_key=$1
    artifact_description=$2
    sed -n "s/^[[:space:]]*${artifact_key}[[:space:]]*=[[:space:]]*//p" \
        "$web_presets" >"$named_artifact_list"
    while IFS= read -r named_artifact; do
        [ -n "$named_artifact" ] || continue
        if [ ! -f "$named_artifact" ]; then
            printf 'preset names %s: %s\n' \
                "$artifact_description" "$named_artifact" >&2
            missing_named_artifacts=$((missing_named_artifacts + 1))
        fi
    done <"$named_artifact_list"
}
count_missing_named_artifacts LLAMA_ARG_MCP_SERVERS_CONFIG \
    'an unreadable MCP configuration'
count_missing_named_artifacts LLAMA_ARG_MMPROJ \
    'a projector that is not a regular file'
rm -f -- "$named_artifact_list"
trap - EXIT HUP INT TERM
if [ "$missing_named_artifacts" -ne 0 ]; then
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

# The approval broker's lifetime is this launch's. A section reaching the
# network through its MCP server signs each search from one human approval, and
# `authorize-broker.py` is the only issuer of that signature, so a web router
# running while nothing issues grants serves a tool every call is refused. This
# marker travels to qwen-webui-session.sh through qwen-webui-control.sh, which
# starts the broker as a guarded child; the ordinary qwen-launch.sh path leaves
# the marker unset and starts no broker.
#
# The signing key reaches the broker as a path in the environment and its
# contents stay in the broker's own address space. A launch that names a key
# file the broker cannot read is refused here, where the reason is legible,
# rather than at the first approval a human has already given.
QWEN_WEB_BROKER=1
QWEN_WEB_BROKER_PORT=${QWEN_WEB_BROKER_PORT:-8571}
QWEN_WEB_STATE_DIR=${QWEN_WEB_STATE_DIR:-$state_directory/web-mcp}
if [ -n "${QWEN_WEB_TOKEN_KEY_FILE:-}" ] && [ ! -r "$QWEN_WEB_TOKEN_KEY_FILE" ]; then
    printf 'the grant signing key is unreadable: %s\n' \
        "$QWEN_WEB_TOKEN_KEY_FILE" >&2
    exit 2
fi
signing_key_state=absent
if [ -n "${QWEN_WEB_TOKEN_KEY_FILE:-}" ]; then
    signing_key_state=configured
    export QWEN_WEB_TOKEN_KEY_FILE
fi
printf 'web_launch broker_port=%s broker_state_dir=%s signing_key=%s\n' \
    "$QWEN_WEB_BROKER_PORT" "$QWEN_WEB_STATE_DIR" "$signing_key_state"

QWEN_ROUTER=1
QWEN_ROUTER_PRESETS=$web_presets
QWEN_ROUTER_MAX=1
QWEN_BIND_HOST=127.0.0.1
export QWEN_ROUTER QWEN_ROUTER_PRESETS QWEN_ROUTER_MAX QWEN_BIND_HOST
export QWEN_WEB_BROKER QWEN_WEB_BROKER_PORT QWEN_WEB_STATE_DIR

exec "$launcher" "$profile"
